// Evim — Supabase bağlantısı (Elçin/Tabu'dan AYRI hesap ve proje).
const supabaseUrl = 'https://hbtypvlsiuqpcbypealk.supabase.co';
const supabaseAnonKey = 'sb_publishable_NJhWjQ1FYuyxjXv2He0lYw_ZVYW5aer';

// Giriş: kullanıcı adı + şifre. E-posta içeride bu alan adıyla üretilir.
const authEmailDomain = 'evim.local';

// Girilen koda içeride eklenen sabit ek (Supabase en az 6 karakter ister;
// gerçek şifre = yazılan kod + bu ek). Böylece haneler kısa kod yazar.
const authPassSuffix = 'evim';
