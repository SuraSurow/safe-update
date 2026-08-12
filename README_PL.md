# Safe Update

**Safe Update** to modularny system aktualizacji, backupu, healthchecków i rollbacku przeznaczony dla serwerów Debian.

Powstał po to, aby rutynowe aktualizacje serwera były bezpieczniejsze. Przed instalacją aktualizacji system sprawdza stan hosta i aplikacji, wykonuje backup danych trwałych, tworzy snapshot systemu, przeprowadza aktualizację, a następnie ponownie weryfikuje działanie serwera.

Projekt jest obecnie przeznaczony głównie dla serwerów Debian wykorzystujących `systemd`, `APT`, `Timeshift` oraz rootless `Podman`.

---

## Informacje o projekcie

- **Projekt:** Safe Update
- **Wersja:** 1.0-test
- **Status:** Eksperymentalny / Testowy
- **Data utworzenia:** 12 sierpnia 2026
- **Autor:** Wojciech Surowiecki
- **Pseudonim:** Bolo
- **GitHub:** `SuraSurow`
- **Licencja:** GNU Affero General Public License v3.0 lub nowsza (`AGPL-3.0-or-later`)

> Safe Update 1.0-test jest wczesną wersją testową.  
> Mechanizm został przetestowany na serwerze Debian 13, ale przed uruchomieniem na nowym systemie produkcyjnym powinien zostać dokładnie zweryfikowany.

---

## Cel projektu

Aktualizacja serwera produkcyjnego nie powinna sprowadzać się wyłącznie do:

```bash
apt upgrade
```

Bezpieczny proces aktualizacji powinien wcześniej odpowiedzieć między innymi na pytania:

- Czy serwer działa poprawnie przed aktualizacją?
- Czy wszystkie ważne dane aplikacji są objęte backupem?
- Czy dumpy baz danych są prawidłowe?
- Czy persistent mounty kontenerów nadal odpowiadają konfiguracji?
- Czy istnieje snapshot umożliwiający cofnięcie systemu?
- Czy aplikacje działają po aktualizacji?
- Czy można odtworzyć poprzedni stan systemu w razie awarii?

Safe Update automatyzuje większość tego procesu.

---

## Funkcje

Safe Update obecnie zapewnia:

- wykrywanie aktualizacji APT
- healthcheck hosta przed aktualizacją
- healthcheck aplikacji przed aktualizacją
- kontrolę persistent storage
- backup baz PostgreSQL
- backup katalogów
- backup wolumenów rootless Podman
- generowanie i weryfikację sum SHA256
- weryfikację archiwów `.tar.gz`
- weryfikację dumpów PostgreSQL
- snapshoty systemu przez Timeshift
- aktualizację systemu przez APT
- healthcheck po aktualizacji
- konfigurowalną retencję backupów
- konfigurowalną retencję snapshotów Timeshift
- ręczny rollback do snapshotu sprzed aktualizacji
- integrację z systemd
- timer systemd do automatycznego uruchamiania
- modularną konfigurację poszczególnych usług

Jeżeli nie ma dostępnych aktualizacji, Safe Update kończy działanie bez tworzenia niepotrzebnego backupu ani snapshota.

---

## Przebieg aktualizacji

```text
Sprawdzenie aktualizacji
            |
            v
     Są aktualizacje?
       /          \
     NIE            TAK
      |              |
      v              v
    KONIEC       Healthcheck przed
                     |
                     v
              Kontrola storage
                     |
                     v
                Backup danych
                     |
                     v
             Weryfikacja backupu
                     |
                     v
              Snapshot Timeshift
                     |
                     v
                Aktualizacja APT
                     |
                     v
              Healthcheck po
                     |
               +-----+-----+
               |           |
             PASS         FAIL
               |           |
               v           v
            Retencja   Zachowanie snapshotu
               |           |
               v           v
             KONIEC    Ręczny rollback
```

Automatyczny rollback całego systemu operacyjnego celowo nie jest domyślnie włączony.

---

## Struktura projektu

```text
safe-update/
├── safe-update
├── install.sh
├── uninstall.sh
├── LICENSE
├── README.md
├── README_PL.md
├── .gitignore
│
├── lib/
│   ├── backup.sh
│   ├── config.sh
│   ├── health.sh
│   ├── inventory.sh
│   ├── report.sh
│   ├── retention.sh
│   ├── rollback.sh
│   ├── snapshot.sh
│   ├── update-check.sh
│   ├── update.sh
│   └── verify.sh
│
├── config/
│   ├── safe-update.conf.example
│   └── services/
│       └── example.conf.example
│
└── systemd/
    ├── safe-update.service
    └── safe-update.timer
```

---

## Wymagania

Safe Update jest obecnie projektowany dla środowiska:

- Debian
- systemd
- APT
- Timeshift
- rsync
- curl
- tar
- narzędzia SHA256
- uprawnienia root

Opcjonalna integracja aplikacyjna skupia się obecnie na:

- rootless Podman
- PostgreSQL

---

## Instalacja

Sklonuj repozytorium:

```bash
git clone <repository-url>
cd safe-update
```

Uruchom instalator:

```bash
sudo ./install.sh
```

Program zostanie zainstalowany w:

```text
/opt/safe-update
```

Konfiguracja znajduje się w:

```text
/etc/safe-update
```

Dane robocze oraz backupy:

```text
/var/lib/safe-update
```

Logi mogą znajdować się w:

```text
/var/log/safe-update
```

Jednostki systemd instalowane są w:

```text
/etc/systemd/system/
```

Instalator **nie włącza automatycznych aktualizacji bezpośrednio po instalacji**.

---

## Konfiguracja globalna

Główny plik konfiguracyjny:

```text
/etc/safe-update/safe-update.conf
```

Przykład:

```bash
TIMESHIFT_DEVICE="/dev/vda4"

BACKUP_RETENTION=7
SNAPSHOT_RETENTION=5

ROOT_DISK_MAX_PERCENT=90
MIN_AVAILABLE_MEMORY_MB=256
```

### Ustalenie urządzenia root

Sprawdź urządzenie zawierające `/`:

```bash
findmnt -no SOURCE /
```

Przykład:

```text
/dev/vda4
```

Przed użyciem snapshotów lub rollbacku należy skonfigurować poprawne urządzenie.

---

## Konfiguracja usług

Każda chroniona aplikacja posiada osobny plik konfiguracyjny:

```text
/etc/safe-update/services/
```

Przykład:

```text
/etc/safe-update/services/example.conf
```

Przykładowa konfiguracja:

```bash
SERVICE_NAME="example"
SERVICE_USER="svc-example"

DB_TYPE="postgres"

DB_CONTAINER="example-postgres"
DB_NAME="example"
DB_USER="example"

BACKUP_PATHS=(
  "/home/svc-example/data"
)

BACKUP_VOLUMES=(
  "example-data"
)

EXPECTED_MOUNTS=(
  "example-postgres|volume|/var/lib/postgresql/data"
  "example-app|volume|/usr/src/example/data"
)

HEALTH_URL="https://example.com/"
```

---

## Kontrola persistent storage

Safe Update porównuje skonfigurowane persistent mounty z mountami aktualnie wykorzystywanymi przez uruchomione kontenery.

Jeżeli:

- pojawi się nowy persistent mount,
- zniknie oczekiwany mount,
- zmieni się układ storage,

pipeline aktualizacji zostanie zatrzymany.

Ma to zapobiec sytuacji, w której nowe dane aplikacji zostaną nieświadomie pominięte podczas backupu.

---

## Backup baz danych

Obecnie dedykowane wsparcie obejmuje:

```text
PostgreSQL
```

Dump PostgreSQL wykonywany jest za pomocą:

```bash
pg_dump -Fc
```

Utworzony dump jest następnie sprawdzany za pomocą narzędzi PostgreSQL.

Dla usług bez bazy danych można ustawić:

```bash
DB_TYPE="none"
```

---

## Healthcheck

### Sprawdzenie hosta

Safe Update może sprawdzać:

- uszkodzone jednostki systemd
- poprawność konfiguracji nginx
- stan usługi nginx
- dostępność reguł nftables
- zajętość głównego filesystemu
- dostępną pamięć RAM

Przykładowe limity:

```bash
ROOT_DISK_MAX_PERCENT=90
MIN_AVAILABLE_MEMORY_MB=256
```

### Sprawdzenie aplikacji

Dla każdej usługi można sprawdzać:

- istnienie konta usługowego
- dostępność rootless Podman
- stan kontenerów
- PostgreSQL poprzez `SELECT 1`
- dostępność endpointu HTTP/HTTPS

Są to smoke testy, a nie pełne testy end-to-end aplikacji.

---

## Polecenia

### Sprawdzenie aktualizacji

```bash
sudo /opt/safe-update/safe-update check
```

### Wykonanie i weryfikacja backupu

```bash
sudo /opt/safe-update/safe-update backup
```

### Uruchomienie całego procesu aktualizacji

```bash
sudo /opt/safe-update/safe-update run
```

### Rollback

```bash
sudo /opt/safe-update/safe-update rollback NAZWA_SNAPSHOTA
```

Przykład:

```bash
sudo /opt/safe-update/safe-update rollback 2026-08-12_17-08-12
```

Timeshift może podczas restore automatycznie zrestartować serwer.

---

## Usługa systemd

Ręczne uruchomienie przez systemd:

```bash
sudo systemctl start safe-update.service
```

Status:

```bash
systemctl status safe-update.service --no-pager
```

Logi:

```bash
sudo journalctl -u safe-update.service
```

---

## Automatyczne uruchamianie

Włączenie timera:

```bash
sudo systemctl enable --now safe-update.timer
```

Sprawdzenie:

```bash
systemctl status safe-update.timer --no-pager
```

lub:

```bash
systemctl list-timers safe-update.timer --no-pager
```

Domyślna konfiguracja uruchamia Safe Update raz dziennie z losowym opóźnieniem.

Automatyczny rollback nie jest obecnie włączony.

---

## Retencja backupów

Retencja backupów aplikacji:

```bash
BACKUP_RETENTION=7
```

Zachowywana jest skonfigurowana liczba najnowszych backupów.

---

## Retencja snapshotów

Retencja snapshotów Safe Update:

```bash
SNAPSHOT_RETENTION=5
```

Mechanizm powinien usuwać wyłącznie snapshoty utworzone przez Safe Update przed aktualizacją.

Inne snapshoty Timeshift nie powinny być przez niego usuwane.

---

## Rollback

Przed instalacją aktualizacji Safe Update tworzy snapshot Timeshift.

Jeżeli healthcheck po aktualizacji zakończy się błędem:

- proces kończy się błędem,
- snapshot sprzed aktualizacji zostaje zachowany,
- wyświetlana jest jego nazwa,
- administrator może uruchomić ręczny rollback.

Przykład:

```bash
sudo /opt/safe-update/safe-update rollback NAZWA_SNAPSHOTA
```

Ręczny rollback w wersji `1.0-test` jest celowym rozwiązaniem.

Chwilowa awaria pojedynczej aplikacji nie powinna automatycznie powodować pełnego cofnięcia systemu operacyjnego bez decyzji administratora.

---

## Logi i raporty

Logi systemd:

```bash
sudo journalctl -u safe-update.service
```

Backupy aplikacji:

```text
/var/lib/safe-update/backups/
```

Informacje o przebiegu aktualizacji:

```text
/var/lib/safe-update/update-check/
```

Katalog backupu może zawierać:

```text
backup.log
report.md
SHA256SUMS
```

---

## Model bezpieczeństwa

Safe Update działa jako `root`.

Jest to konieczne, ponieważ program potrzebuje dostępu do:

- APT
- Timeshift
- chronionych plików systemowych
- systemd
- stanu firewalla
- systemowych katalogów backupu
- wielu kont usługowych rootless Podman

Zalecane prawa:

```text
/opt/safe-update                   root:root 700
/etc/safe-update                   root:root 700
/etc/safe-update/safe-update.conf  root:root 600
/etc/safe-update/services/*.conf   root:root 600
/var/lib/safe-update               root:root 700
```

Konta usługowe powinny działać zgodnie z zasadą minimalnych uprawnień.

Safe Update nie powinien wymagać przyznawania kontom aplikacyjnym dostępu do `sudo`.

---

## Odinstalowanie

Uruchom:

```bash
sudo ./uninstall.sh
```

Uninstaller usuwa program oraz jednostki systemd.

Ze względów bezpieczeństwa celowo pozostawia:

```text
/etc/safe-update
/var/lib/safe-update
/var/log/safe-update
```

Zapobiega to przypadkowemu skasowaniu konfiguracji i backupów.

---

## Zalecana procedura wdrożenia

Przed włączeniem automatycznego działania na nowym serwerze:

1. Zainstaluj Safe Update.
2. Skonfiguruj ustawienia globalne.
3. Dodaj wszystkie chronione aplikacje.
4. Zweryfikuj inventory persistent storage.
5. Wykonaj ręczny backup.
6. Zweryfikuj backup baz danych i plików.
7. Uruchom healthcheck.
8. Utwórz snapshot Timeshift.
9. Wykonaj kontrolowany test rollbacku.
10. Uruchom ręcznie pełny pipeline aktualizacji.
11. Potwierdź prawidłowe działanie aplikacji.
12. Włącz `safe-update.timer`.

Nie należy zakładać, że rollback będzie działał identycznie na każdym serwerze bez wcześniejszego testu.

---

## Aktualne ograniczenia

Wersja `1.0-test` ma obecnie następujące ograniczenia:

- testowana głównie na Debian 13
- automatyczny rollback jest wyłączony
- dedykowany backup baz obsługuje obecnie PostgreSQL
- integracja kontenerowa skupia się na rootless Podman
- healthchecki są smoke testami
- zachowanie Timeshift może zależeć od układu partycji i bootloadera
- pierwszy rzeczywisty update na nowym serwerze powinien być nadzorowany
- projekt jest nadal wersją eksperymentalną

---

## Przetestowane środowisko referencyjne

Pierwsza wersja została rozwinięta i przetestowana w środowisku:

```text
Debian 13
systemd
APT
Timeshift w trybie RSYNC
rootless Podman
PostgreSQL w kontenerach
nginx
nftables
```

Rollback został przetestowany na systemie posiadającym osobne filesystemy dla root, `/boot` oraz `/boot/efi`.

Nie oznacza to gwarancji identycznego działania na innym układzie storage.

---

## Wersja

### 1.0-test — 2026-08-12

Pierwsza wersja testowa projektu.

Zaimplementowano:

- modularną konfigurację
- wykrywanie aktualizacji APT
- inventory persistent storage
- backup danych aplikacji
- dumpy PostgreSQL
- weryfikację backupów
- snapshoty Timeshift
- healthcheck hosta i aplikacji
- pipeline aktualizacji
- ręczny rollback
- retencję backupów
- retencję snapshotów
- usługę systemd
- automatyczny timer systemd
- strukturę umożliwiającą przenoszenie projektu pomiędzy serwerami

---

## Autor

**Wojciech Surowiecki**

Pseudonim:

**Bolo**

GitHub:

**SuraSurow**

Projekt utworzony **12 sierpnia 2026 r.**

---

## Licencja

Copyright © 2026 Wojciech Surowiecki

Projekt jest udostępniany na licencji **GNU Affero General Public License v3.0 lub nowszej (`AGPL-3.0-or-later`)**.

Kod można używać, analizować, modyfikować oraz rozpowszechniać zgodnie z warunkami GNU Affero General Public License.

Jeżeli powstaje zmodyfikowana praca objęta AGPL i jest rozpowszechniana albo używana w sposób uruchamiający wymagania AGPL dotyczące udostępnienia kodu przez sieć, odpowiedni kod źródłowy musi zostać udostępniony zgodnie z warunkami tej licencji.

Pełny tekst licencji znajduje się w pliku `LICENSE`.

Safe Update jest dostarczany **bez gwarancji**, w zakresie dozwolonym przez obowiązujące prawo.
