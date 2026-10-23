<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Validation\ValidationException;
use SimpleXMLElement;
use ZipArchive;

class GradeSpreadsheetReader
{
    /** @return list<array{matricule: string, note: string, situation: string}> */
    public function read(UploadedFile $file): array
    {
        $extension = strtolower($file->getClientOriginalExtension());
        $rows = match ($extension) {
            'csv', 'txt' => $this->readCsv($file->getRealPath()),
            'xlsx' => $this->readXlsx($file->getRealPath()),
            default => throw ValidationException::withMessages(['fichier' => ['Utilisez un fichier CSV ou XLSX.']]),
        };

        if ($rows === []) {
            throw ValidationException::withMessages(['fichier' => ['Le fichier ne contient aucune ligne de notes.']]);
        }

        return $this->normalizeRows($rows);
    }

    /**
     * Read a whole gradebook while preserving its columns for CC, TP, TPE and SN.
     *
     * @return array{headers: list<string>, rows: list<list<string>>}
     */
    public function readTable(UploadedFile $file): array
    {
        $extension = strtolower($file->getClientOriginalExtension());
        $rows = match ($extension) {
            'csv', 'txt' => $this->readCsv($file->getRealPath()),
            'xlsx' => $this->readXlsx($file->getRealPath()),
            default => throw ValidationException::withMessages(['fichier' => ['Utilisez un fichier CSV ou XLSX.']]),
        };
        if ($rows === []) {
            throw ValidationException::withMessages(['fichier' => ['Le fichier ne contient aucune ligne.']]);
        }

        $headerOffset = 0;
        $searchRows = array_slice($rows, 0, 10, true);
        foreach ($searchRows as $offset => $candidateRow) {
            $candidateHeaders = array_map(fn (string $header): string => $this->normalizeHeader($header), $candidateRow);
            $hasMatricule = array_filter($candidateHeaders, static fn (string $header): bool => str_contains($header, 'matricule')) !== [];
            $hasEvaluation = array_filter($candidateHeaders, static function (string $header): bool {
                $header = preg_replace('/_(?:sur_)?20$/', '', $header) ?? $header;

                return preg_match('/^(?:note_)?(cc|tp|tpe|sn)(?:_\d+)?$/', $header) === 1;
            }) !== [];
            if ($hasMatricule && $hasEvaluation) {
                $headerOffset = (int) $offset;
                break;
            }
        }
        $rows = array_values(array_slice($rows, $headerOffset));
        $headers = array_map(fn (string $header): string => $this->normalizeHeader($header), array_shift($rows) ?? []);
        $rows = array_map(static function (array $row) use ($headers): array {
            return array_map(static fn (int $index): string => trim((string) ($row[$index] ?? '')), array_keys($headers));
        }, $rows);

        return ['headers' => $headers, 'rows' => $rows];
    }

    /** @return list<list<string>> */
    private function readCsv(string $path): array
    {
        $handle = fopen($path, 'rb');
        if ($handle === false) {
            throw ValidationException::withMessages(['fichier' => ['Le fichier ne peut pas être lu.']]);
        }

        try {
            $firstLine = fgets($handle);
            if ($firstLine === false) {
                return [];
            }
            rewind($handle);
            $delimiters = [',' => substr_count($firstLine, ','), ';' => substr_count($firstLine, ';'), "\t" => substr_count($firstLine, "\t")];
            arsort($delimiters);
            $delimiter = (string) array_key_first($delimiters);
            $rows = [];
            while (($row = fgetcsv($handle, separator: $delimiter)) !== false) {
                $rows[] = array_map(static fn (mixed $value): string => trim((string) $value), $row);
            }

            return $rows;
        } finally {
            fclose($handle);
        }
    }

    /** @return list<list<string>> */
    private function readXlsx(string $path): array
    {
        if (! class_exists(ZipArchive::class)) {
            throw ValidationException::withMessages(['fichier' => ['Le serveur PHP doit activer l’extension ZIP pour lire les fichiers XLSX.']]);
        }
        $archive = new ZipArchive;
        if ($archive->open($path) !== true) {
            throw ValidationException::withMessages(['fichier' => ['Le fichier XLSX est illisible ou endommagé.']]);
        }

        try {
            $totalSize = 0;
            for ($index = 0; $index < $archive->numFiles; $index++) {
                $entry = $archive->statIndex($index);
                $totalSize += (int) ($entry['size'] ?? 0);
                if ($totalSize > 50 * 1024 * 1024) {
                    throw ValidationException::withMessages(['fichier' => ['Le contenu décompressé du fichier dépasse la limite autorisée.']]);
                }
            }
            $workbookXml = $this->xml($archive->getFromName('xl/workbook.xml'));
            $relationshipsXml = $this->xml($archive->getFromName('xl/_rels/workbook.xml.rels'));
            $sheetNodes = $workbookXml->sheets->sheet ?? null;
            if ($sheetNodes === null || count($sheetNodes) === 0) {
                throw ValidationException::withMessages(['fichier' => ['Le classeur ne contient aucune feuille.']]);
            }
            $relationshipNamespace = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
            $relationshipId = (string) $sheetNodes[0]->attributes($relationshipNamespace)['id'];
            $target = null;
            foreach ($relationshipsXml->Relationship as $relationship) {
                if ((string) $relationship['Id'] === $relationshipId) {
                    $target = (string) $relationship['Target'];
                    break;
                }
            }
            if ($target === null || str_contains($target, '..')) {
                throw ValidationException::withMessages(['fichier' => ['La première feuille du classeur est introuvable.']]);
            }
            $sheetPath = str_starts_with($target, 'xl/') ? $target : 'xl/'.ltrim($target, '/');
            $sheetXml = $this->xml($archive->getFromName($sheetPath));
            $sharedStrings = [];
            $sharedXml = $archive->getFromName('xl/sharedStrings.xml');
            if ($sharedXml !== false) {
                foreach ($this->xml($sharedXml)->si as $item) {
                    $sharedStrings[] = $this->textNodes($item);
                }
            }

            $rows = [];
            foreach ($sheetXml->sheetData->row ?? [] as $rowNode) {
                $cells = [];
                foreach ($rowNode->c ?? [] as $cell) {
                    $reference = (string) $cell['r'];
                    preg_match('/^[A-Z]+/i', $reference, $matches);
                    if ($matches === []) {
                        continue;
                    }
                    $column = $this->columnIndex(strtoupper($matches[0]));
                    $type = (string) $cell['t'];
                    $value = $type === 'inlineStr' ? $this->textNodes($cell->is) : (string) ($cell->v ?? '');
                    if ($type === 's') {
                        $value = $sharedStrings[(int) $value] ?? '';
                    }
                    $cells[$column] = trim($value);
                }
                if ($cells !== []) {
                    ksort($cells);
                    $lastColumn = (int) array_key_last($cells);
                    $row = array_fill(0, $lastColumn + 1, '');
                    foreach ($cells as $column => $value) {
                        $row[$column] = $value;
                    }
                    $rows[] = $row;
                }
            }

            return $rows;
        } finally {
            $archive->close();
        }
    }

    /** @param list<list<string>> $rows
     * @return list<array{matricule: string, note: string, situation: string}>
     */
    private function normalizeRows(array $rows): array
    {
        $headers = array_map(fn (string $header): string => $this->normalizeHeader($header), array_shift($rows) ?? []);
        $matriculeIndex = array_search('matricule', $headers, true);
        $noteIndex = null;
        foreach (['note', 'note_sur_20', 'note_20', 'valeur_note', 'grade'] as $candidate) {
            $candidateIndex = array_search($candidate, $headers, true);
            if ($candidateIndex !== false) {
                $noteIndex = $candidateIndex;
                break;
            }
        }
        $situationIndex = array_search('situation', $headers, true);
        if ($matriculeIndex === false || $noteIndex === null) {
            throw ValidationException::withMessages(['fichier' => ['Les colonnes requises sont matricule et note (sur 20). La colonne situation est facultative.']]);
        }

        $normalized = [];
        foreach ($rows as $row) {
            $matricule = trim((string) ($row[$matriculeIndex] ?? ''));
            $note = trim((string) ($row[$noteIndex] ?? ''));
            $situation = $situationIndex === false ? '' : strtoupper(trim((string) ($row[$situationIndex] ?? '')));
            if ($matricule === '' && $note === '' && $situation === '') {
                continue;
            }
            $normalized[] = ['matricule' => $matricule, 'note' => $note, 'situation' => $situation];
        }

        return $normalized;
    }

    private function normalizeHeader(string $header): string
    {
        $ascii = iconv('UTF-8', 'ASCII//TRANSLIT//IGNORE', $header);
        $normalized = strtolower(trim((string) $ascii));
        $normalized = preg_replace('/[^a-z0-9]+/', '_', $normalized) ?? '';

        return trim($normalized, '_');
    }

    private function columnIndex(string $letters): int
    {
        $index = 0;
        foreach (str_split($letters) as $letter) {
            $index = ($index * 26) + ord($letter) - ord('A') + 1;
        }

        return $index - 1;
    }

    private function textNodes(SimpleXMLElement $node): string
    {
        $text = '';
        foreach ($node->xpath('.//*[local-name()="t"]') ?: [] as $textNode) {
            $text .= (string) $textNode;
        }

        return $text;
    }

    private function xml(string|false $contents): SimpleXMLElement
    {
        if ($contents === false) {
            throw ValidationException::withMessages(['fichier' => ['Le fichier XLSX ne contient pas les métadonnées attendues.']]);
        }
        $xml = simplexml_load_string($contents, SimpleXMLElement::class, LIBXML_NONET | LIBXML_NOBLANKS);
        if ($xml === false) {
            throw ValidationException::withMessages(['fichier' => ['Les données XML du fichier XLSX sont invalides.']]);
        }

        return $xml;
    }
}
