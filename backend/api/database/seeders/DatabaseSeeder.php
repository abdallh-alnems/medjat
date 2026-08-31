<?php

declare(strict_types=1);

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     *
     * The schema is owned by the existing backend's migration ledger while the
     * strangler migration runs, so there is nothing to seed here yet: local data
     * comes from a production dump loaded into medjat_laravel.
     */
    public function run(): void
    {
        //
    }
}
