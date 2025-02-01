Berikut dokumentasi detail untuk flow journey dan halaman yang perlu dibuat:

Semua Informasi yang ada disini adalah dasar kerangka berpikir untuk mengembangkan aplikasi, dan perlu di referensikan dengan update yang ada di file yang ada, untuk menghindari Overwrite / Re-Create.
Dengan cara melihat update ke commit log.

Lalu untuk update backend postgreSQL Supabase, bisa melihat ke schema.sql
dan untuk Update Progress tracker, bisa melihat ke To Do Next.md

Dan setiap melakukan update, wajib update juga ke file tersebut, lengkap dengan log nya.

Semua file ini berada di main dir.

# Dokumentasi Flow Journey CRM App - Auth & Role Staging

## 1. Struktur Hirarki Role
- Super Admin: Akses penuh ke seluruh sistem & seluruh admin
- Admin: Akses CRUD ke semua level dibawahnya
- Head of Division: Akses CRUD ke Manager dan Staff dibawah nya
- Manager: Akses CRUD ke Staff dibawahnya
- Staff: Akses Crud ke diri sendiri

## 2. Flow Onboarding Process (Pembuatan auth system, terbagi menjadi 3 page, Register, Login, Forgotpassword page, pengisian detil terhadap pendaftaran kita fokuskan di onboarding process)

### ONBOARDING PROCESS 
### A. Welcoming Message Page
- Halaman pertama setelah registrasi berhasil
- Menampilkan welcome message yang hangat
- Tombol "Get Started" untuk memulai proses
- Progress indicator menunjukkan step 1/4

### B. Company Type Selection Page
- Pilihan antara "New Company" atau "Existing Company"
- Penjelasan perbedaan kedua opsi
- Progress indicator 2/4

### C. Company Information Form
*New Company Path:*
- Form lengkap:
  - Nama Perusahaan
  - Kode Perusahaan (generated unique)
  - Alamat Lengkap
  - Informasi Kontak
  - Dokumen Legal (opsional)
- Status otomatis menjadi Super Admin

*Existing Company Path:*
- Form basic:
  - Kode Perusahaan (validation required)
  - Kode Atasan/Supervisor (validation required)
  - Informasi Dasar Kontak
- Sistem melakukan validasi:
  1. Cek keberadaan kode perusahaan
  2. Cek keberadaan supervisor
  3. Cross-check email supervisor
- Progress indicator 3/4

### D. Agreement Page
- Terms & Conditions
- Privacy Policy
- Data Usage Agreement
- Checkbox untuk persetujuan
- Progress indicator 4/4

## 3. Validasi & Security Rules

### A. Validasi Onboarding
- User tidak bisa mengakses main app sebelum onboarding selesai
- Status onboarding disimpan di database
- Redirect ke last incomplete step jika proses terputus

### B. RBAC Validation Rules
- Validasi hirarki sebelum setiap operasi CRUD
- Cek company_id untuk memastikan operasi dalam satu perusahaan
- Validasi supervisor level sebelum assignment

## 4. Custom Roles Management

### A. Custom Role Creation Page
- Form untuk membuat jabatan custom
- Mapping ke level hirarki yang ada
- Validasi nama jabatan (unique per company)

### B. Role Assignment Page
- Interface untuk assign user ke custom role
- Validasi hirarki sebelum assignment
- Konfirmasi perubahan role

## 5. Technical Considerations

### A. Database Triggers
- Auto-update timestamps
- Validation triggers untuk hirarki
- Logging untuk audit trail

### B. Security Features
- Row Level Security (RLS)
- Encrypted passwords
- Session management
- Rate limiting untuk API calls

Gunakan logika rules, bisa di restrict dari Front End, dan Mostly dati Backend, gunakan logika pemisahan rules ini agar menghindari konflik recursive infinite loop.

Standard integrity sql pastikan tidak terlalu kompleks, hanya saja pastikan logika integrity sesuai standard

Setelah semua Fase ini selesai, kita akan masuk ke **Fase 2.**
