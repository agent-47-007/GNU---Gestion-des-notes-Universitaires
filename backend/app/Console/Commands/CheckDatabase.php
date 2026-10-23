<?php

namespace App\Console\Commands;

use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

#[Signature('app:check-database')]
#[Description('Command description')]
class CheckDatabase extends Command
{
    /**
     * Execute the console command.
     */
    public function handle()
    {
        //
    }
}
