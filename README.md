# Money Memo

แอป Flutter Android สำหรับบันทึกรายรับรายจ่าย ใช้งานเองในเครื่อง โดยใช้ Docker เป็น environment หลัก เครื่อง Windows ไม่ต้องติดตั้ง Flutter, Android Studio, Android SDK, Java หรือ Gradle

## สิ่งที่มีใน Phase 1

- Dashboard: ยอดคงเหลือ, รายรับ/รายจ่ายเดือนนี้, รายการล่าสุด 5 รายการ
- Transaction: เพิ่ม/แก้ไข/ลบ รายรับและรายจ่าย
- Category: หมวดหมู่เริ่มต้นภาษาไทย และเพิ่ม/แก้ไข/ลบได้
- Wallet: กระเป๋าเงินเริ่มต้น, balance แยกกระเป๋า, recalculate หลังแก้ transaction
- Transaction List: filter เดือน, type, category, wallet และค้นหา note
- Monthly Summary: รายรับรวม, รายจ่ายรวม, balance สุทธิ, รายจ่ายแยกตามหมวดหมู่
- Export CSV: columns `date,type,amount,category,wallet,note`
- Backup / Restore: backup SQLite และ restore พร้อม confirmation

## ติดตั้ง Docker Desktop บน Windows แบบคร่าว ๆ

1. ติดตั้ง Docker Desktop จาก https://www.docker.com/products/docker-desktop/
2. เปิด Docker Desktop ให้เรียบร้อย
3. แนะนำให้เปิด WSL 2 backend ตาม wizard ของ Docker Desktop
4. เปิด PowerShell แล้วเช็ก:

```powershell
docker --version
docker compose version
```

## Clone / Open Project

```powershell
git clone <repo-url> money_memo
cd money_memo
```

ถ้าเปิดจากไฟล์ที่มีอยู่แล้ว ให้เปิด PowerShell ที่โฟลเดอร์โปรเจกต์นี้

## Build Docker Image

ครั้งแรกจะใช้เวลานานเพราะต้องดึง Flutter stable + Android SDK:

```powershell
docker compose build
```

เช็ก Flutter doctor:

```powershell
docker compose run --rm flutter flutter doctor
```

ถ้ามี Android license ให้รัน:

```powershell
docker compose run --rm flutter flutter doctor --android-licenses
```

## สร้าง Flutter Project ครั้งแรก

โปรเจกต์นี้เตรียมไฟล์ไว้แล้ว แต่ถ้าต้องการ regenerate scaffold จาก Flutter:

```powershell
docker compose run --rm flutter flutter create --project-name money_memo --platforms android .
```

หลัง regenerate ให้ตรวจ diff ก่อนเสมอ เพราะคำสั่งนี้อาจเขียนทับไฟล์ template บางส่วน

## ติดตั้ง dependencies

```powershell
docker compose run --rm flutter flutter pub get
```

## Generate Drift Files

Phase 1 ใช้ drift เป็น SQLite executor โดยไม่บังคับใช้ generated table files แต่เตรียม dev dependency ไว้แล้ว คำสั่งนี้ยังรันได้เมื่อเพิ่ม generated tables ในอนาคต:

```powershell
docker compose run --rm flutter dart run build_runner build --delete-conflicting-outputs
```

## Analyze และ Test

```powershell
docker compose run --rm flutter flutter analyze
docker compose run --rm flutter flutter test
```

## Build APK

```powershell
docker compose run --rm flutter flutter build apk --release
```

ไฟล์ APK จะอยู่ที่:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## ติดตั้ง APK บนมือถือจริง

1. Build APK ด้วยคำสั่งด้านบน
2. ส่งไฟล์ `build/app/outputs/flutter-apk/app-release.apk` ไปมือถือ เช่น USB, Google Drive, Nearby Share หรือ LINE
3. เปิดไฟล์ APK บนมือถือ
4. อนุญาต Install unknown apps ถ้า Android ถาม
5. ติดตั้งและเปิดแอป Money Memo

## คำสั่ง Docker ที่ใช้บ่อย

```powershell
docker compose run --rm flutter flutter doctor
docker compose run --rm flutter flutter pub get
docker compose run --rm flutter dart run build_runner build --delete-conflicting-outputs
docker compose run --rm flutter flutter analyze
docker compose run --rm flutter flutter test
docker compose run --rm flutter flutter build apk --release
```

## แก้ปัญหาเบื้องต้น

Android SDK license:

```powershell
docker compose run --rm flutter flutter doctor --android-licenses
```

Gradle cache เพี้ยนหรือต้องการล้าง cache:

```powershell
docker compose down
docker volume rm money-memo_flutter-gradle-cache
docker compose build --no-cache
```

Pub cache เพี้ยน:

```powershell
docker volume rm money-memo_flutter-pub-cache
docker compose run --rm flutter flutter pub get
```

Permission หรือไฟล์ build บน Windows มีปัญหา:

```powershell
docker compose run --rm flutter flutter clean
docker compose run --rm flutter flutter pub get
```

Docker Desktop ไม่พร้อม:

- เปิด Docker Desktop ก่อนรันคำสั่ง
- เช็กว่า WSL 2 backend ทำงานอยู่
- รีสตาร์ท Docker Desktop แล้วลองใหม่

## โครงสร้างโปรเจกต์

```text
lib/
  main.dart
  app/
  core/
  database/
  features/
    dashboard/
    transactions/
    categories/
    wallets/
    reports/
    export/
    backup/
    shared/
  repositories/
  shared/
```

## Roadmap

Phase 2:
- OCR อ่านรูปจาก Gallery
- แนบรูปสลิป/ใบเสร็จ
- Import CSV
- Export Excel
- Export PDF
- Budget รายเดือน

Phase 3:
- PIN lock
- Biometric
- Tag
- รายงานขั้นสูง
- Recurring transaction
- แจ้งเตือนรายจ่าย
- Dashboard chart ขั้นสูง
- Backup แบบเข้ารหัส
