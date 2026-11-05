<?php

namespace App\Services;

use RuntimeException;
use ZipArchive;

class GradeWorkbookWriter
{
    /** @param list<array{name: string, rows: list<list<mixed>>}> $sheets */
    public function write(array $sheets): string
    {
        if (! class_exists(ZipArchive::class)) {
            abort(503, 'L’extension PHP ZIP doit être activée pour générer un fichier Excel.');
        }
        if ($sheets === []) {
            throw new RuntimeException('Le classeur doit contenir au moins une feuille.');
        }

        $path = tempnam(sys_get_temp_dir(), 'gnu-xlsx-');
        if ($path === false) {
            throw new RuntimeException('Impossible de préparer le fichier Excel.');
        }
        $archive = new ZipArchive;
        $opened = false;
        try {
            if ($archive->open($path, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== true) {
                throw new RuntimeException('Impossible de créer le classeur Excel.');
            }
            $opened = true;

            $overrides = '';
            $sheetLinks = '';
            foreach ($sheets as $index => $sheet) {
                $number = $index + 1;
                $safeName = mb_substr(trim($sheet['name']) ?: 'Feuille '.$number, 0, 31);
                $sheetLinks .= '<sheet name="'.$this->xml($safeName).'" sheetId="'.$number.'" r:id="rId'.$number.'"/>';
                $overrides .= '<Override PartName="/xl/worksheets/sheet'.$number.'.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>';
                $archive->addFromString('xl/worksheets/sheet'.$number.'.xml', $this->worksheet($sheet['rows']));
            }
            $styleId = count($sheets) + 1;
            $relationships = '';
            foreach ($sheets as $index => $_sheet) {
                $number = $index + 1;
                $relationships .= '<Relationship Id="rId'.$number.'" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet'.$number.'.xml"/>';
            }
            $relationships .= '<Relationship Id="rId'.$styleId.'" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>';

            $archive->addFromString('[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'.$overrides.'</Types>');
            $archive->addFromString('_rels/.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>');
            $archive->addFromString('xl/workbook.xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><bookViews><workbookView/></bookViews><sheets>'.$sheetLinks.'</sheets></workbook>');
            $archive->addFromString('xl/_rels/workbook.xml.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'.$relationships.'</Relationships>');
            $archive->addFromString('xl/styles.xml', $this->styles());
            $archive->close();
            $opened = false;

            $contents = file_get_contents($path);
            if ($contents === false) {
                throw new RuntimeException('Impossible de lire le classeur Excel généré.');
            }

            return $contents;
        } finally {
            if ($opened) {
                $archive->close();
            }
            @unlink($path);
        }
    }

    /** @param list<list<mixed>> $rows */
    private function worksheet(array $rows): string
    {
        $maxColumns = max(1, ...array_map(static fn (array $row): int => count($row), $rows));
        $lastColumn = $this->columnName($maxColumns);
        $lastRow = max(1, count($rows));
        $xml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><sheetFormatPr defaultRowHeight="18"/><sheetData>';
        foreach ($rows as $rowIndex => $row) {
            $excelRow = $rowIndex + 1;
            $xml .= '<row r="'.$excelRow.'">';
            foreach ($row as $columnIndex => $value) {
                if ($value === null || $value === '') {
                    continue;
                }
                $cell = $this->columnName($columnIndex + 1).$excelRow;
                $style = $rowIndex === 0 ? ' s="1"' : '';
                if (is_int($value) || (is_float($value) && is_finite($value))) {
                    $xml .= '<c r="'.$cell.'"'.$style.'><v>'.$value.'</v></c>';
                } else {
                    $text = is_scalar($value) ? (string) $value : json_encode($value, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE);
                    $xml .= '<c r="'.$cell.'" t="inlineStr"'.$style.'><is><t xml:space="preserve">'.$this->xml($text).'</t></is></c>';
                }
            }
            $xml .= '</row>';
        }
        $xml .= '</sheetData><autoFilter ref="A1:'.$lastColumn.$lastRow.'"/></worksheet>';

        return $xml;
    }

    private function styles(): string
    {
        return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><color rgb="FFFFFFFF"/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF0F766E"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="1" borderId="0" xfId="0" applyFont="1" applyFill="1"/></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>';
    }

    private function columnName(int $number): string
    {
        $name = '';
        while ($number > 0) {
            $number--;
            $name = chr(65 + ($number % 26)).$name;
            $number = intdiv($number, 26);
        }

        return $name;
    }

    private function xml(string $value): string
    {
        return htmlspecialchars($value, ENT_XML1 | ENT_QUOTES, 'UTF-8');
    }
}
