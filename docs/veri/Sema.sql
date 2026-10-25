-- =====================================================================================================
--  YÜKÜM — VERİTABANI ŞEMASI (SQL Server)
--  Bu dosya OKUMA içindir (açıklamalı özet). Gerçek şema, kodun içindeki "migration"larla üretilir ve
--  veritabanına  dotnet ef database update  komutuyla uygulanır; bu SQL'i elle çalıştırmayın.
--  SQL, EF Core'un backend/src/Yukum.Infrastructure/Persistence/Migrations altındaki migration'lardan ürettiği
--  gerçek komutlardır (dotnet ef migrations script); yalnız tablo/indeks kısmı ve açıklamalar alınmıştır
--  (il/ilçe/rol başlangıç verisi olan 1000+ INSERT satırı çıkarıldı).
--
--  Okuma ipucu: her tablonun üstünde ne işe yaradığı, her sütunun yanında (-- ile) açıklaması vardır.
--  PK = birincil anahtar (satırı tek tanıyan sütun)   FK = yabancı anahtar (başka tabloya bağ)
--  NOT NULL = boş olamaz   NULL = boş olabilir   UNIQUE = tekrar edemez
-- =====================================================================================================

-- ---------------------------------------------------------------------------------------------
-- TABLO Cities: 81 il. Sabit referans verisi (seed). Id = plaka kodu.
-- ---------------------------------------------------------------------------------------------
CREATE TABLE [Cities] (
    [Id] int NOT NULL,  -- Plaka kodu (1-81). Veritabanı üretmez, seed'den gelir.
    [Name] nvarchar(50) NOT NULL,  -- İlin adı. Benzersiz.
    [Latitude] float NOT NULL,  -- İl merkezinin enlemi (derece).
    [Longitude] float NOT NULL,  -- İl merkezinin boylamı (derece).
    CONSTRAINT [PK_Cities] PRIMARY KEY ([Id])  -- PK: bu sütun(lar) satırı tek tanır
);
CREATE UNIQUE INDEX [IX_Cities_Name] ON [Cities] ([Name]);   -- UNIQUE: tekrar edemez

-- ---------------------------------------------------------------------------------------------
-- TABLO Districts: 973 ilçe. Sabit referans verisi (seed). Her ilçe bir ile bağlı.
-- ---------------------------------------------------------------------------------------------
CREATE TABLE [Districts] (
    [Id] int NOT NULL,  -- İlçe numarası (1-973): plaka sırası, sonra Türkçe alfabetik. DONMUŞTUR, değişmez.
    [CityId] int NOT NULL,  -- Bağlı olduğu ilin plaka kodu (yabancı anahtar → Cities.Id).
    [Name] nvarchar(100) NOT NULL,  -- İlçe adı. Aynı ilde benzersiz.
    [Latitude] float NOT NULL,  -- İlçe merkezinin enlemi.
    [Longitude] float NOT NULL,  -- İlçe merkezinin boylamı.
    CONSTRAINT [PK_Districts] PRIMARY KEY ([Id]),  -- PK: bu sütun(lar) satırı tek tanır
    CONSTRAINT [FK_Districts_Cities_CityId] FOREIGN KEY ([CityId]) REFERENCES [Cities] ([Id]) ON DELETE NO ACTION  -- FK: bağlı kayıt silinemez (olmayan kayda işaret edilemez)
);
CREATE UNIQUE INDEX [IX_Districts_CityId_Name] ON [Districts] ([CityId], [Name]);   -- UNIQUE: tekrar edemez

-- ---------------------------------------------------------------------------------------------
-- TABLO Roles: 3 rol: Admin, Shipper (Yük Veren), Carrier (Taşımacı). Seed ile gelir.
-- ---------------------------------------------------------------------------------------------
CREATE TABLE [Roles] (
    [Id] uniqueidentifier NOT NULL,  -- Rolün sabit numarası.
    [Name] nvarchar(256) NULL,  -- Rol adı (Admin / Shipper / Carrier).
    [NormalizedName] nvarchar(256) NULL,  -- Identity'nin aramada kullandığı BÜYÜK harfli ad.
    [ConcurrencyStamp] nvarchar(max) NULL,  -- Identity'nin eşzamanlılık damgası.
    CONSTRAINT [PK_Roles] PRIMARY KEY ([Id])  -- PK: bu sütun(lar) satırı tek tanır
);
CREATE UNIQUE INDEX [RoleNameIndex] ON [Roles] ([NormalizedName]) WHERE [NormalizedName] IS NOT NULL;   -- UNIQUE: tekrar edemez

-- ---------------------------------------------------------------------------------------------
-- TABLO Users: Giriş yapabilen herkes (Yük Veren, Taşımacı, Admin). ASP.NET Core Identity tablosu + bizim sütunlarımız.
-- ---------------------------------------------------------------------------------------------
CREATE TABLE [Users] (
    [Id] uniqueidentifier NOT NULL,  -- Kullanıcı numarası (GUID, tahmin edilemez).
    [FullName] nvarchar(150) NOT NULL,  -- Ad-soyad ya da firma adı.
    [UserType] int NOT NULL,  -- 1=Shipper, 2=Carrier, 3=Admin. Kayıt ucundan gelir, istemciden asla.
    [IsActive] bit NOT NULL,  -- Hesap etkin mi?
    [IsBlocked] bit NOT NULL,  -- Yönetici tarafından engellendi mi?
    [AvatarUrl] nvarchar(500) NULL,  -- Profil fotoğrafı adresi (opsiyonel).
    [KvkkAcceptedAt] datetime2 NULL,  -- KVKK metnini kabul ettiği an (UTC).
    [CreatedAt] datetime2 NOT NULL,  -- Oluşturulma zamanı (UTC), otomatik.
    [UpdatedAt] datetime2 NULL,  -- Son değişiklik zamanı (UTC), otomatik.
    [UserName] nvarchar(256) NULL,  -- Giriş adı = e-posta.
    [NormalizedUserName] nvarchar(256) NULL,  -- Identity: büyük harfli giriş adı (arama için).
    [Email] nvarchar(256) NULL,  -- E-posta (küçük harfle saklanır).
    [NormalizedEmail] nvarchar(256) NULL,  -- Identity: büyük harfli e-posta (benzersizlik buradan denetlenir).
    [EmailConfirmed] bit NOT NULL,  -- E-posta doğrulandı mı? (Doğrulama henüz yok, hep 0.)
    [PasswordHash] nvarchar(max) NULL,  -- Şifrenin HASH'i (PBKDF2). Şifrenin kendisi ASLA saklanmaz.
    [SecurityStamp] nvarchar(max) NULL,  -- Identity: şifre/rol değişince değişir.
    [ConcurrencyStamp] nvarchar(max) NULL,  -- Identity: eşzamanlılık damgası.
    [PhoneNumber] nvarchar(450) NULL,  -- Telefon, +905XXXXXXXXX biçiminde. Benzersiz.
    [PhoneNumberConfirmed] bit NOT NULL,  -- Telefon doğrulandı mı? (henüz yok)
    [TwoFactorEnabled] bit NOT NULL,  -- İki adımlı doğrulama (kullanılmıyor).
    [LockoutEnd] datetimeoffset NULL,  -- Hesap kilidinin biteceği an. Boşsa kilit yok.
    [LockoutEnabled] bit NOT NULL,  -- Bu hesap kilitlenebilir mi? (evet)
    [AccessFailedCount] int NOT NULL,  -- Üst üste hatalı şifre sayısı. 5'te kilit.
    CONSTRAINT [PK_Users] PRIMARY KEY ([Id])  -- PK: bu sütun(lar) satırı tek tanır
);
CREATE UNIQUE INDEX [EmailIndex] ON [Users] ([NormalizedEmail]) WHERE [NormalizedEmail] IS NOT NULL;   -- UNIQUE: tekrar edemez
CREATE UNIQUE INDEX [IX_Users_PhoneNumber] ON [Users] ([PhoneNumber]) WHERE [PhoneNumber] IS NOT NULL;   -- UNIQUE: tekrar edemez
CREATE UNIQUE INDEX [UserNameIndex] ON [Users] ([NormalizedUserName]) WHERE [NormalizedUserName] IS NOT NULL;   -- UNIQUE: tekrar edemez

-- ---------------------------------------------------------------------------------------------
-- TABLO UserRoles: Hangi kullanıcı hangi rolde (kullanıcı başına tek rol).
-- ---------------------------------------------------------------------------------------------
CREATE TABLE [UserRoles] (
    [UserId] uniqueidentifier NOT NULL,  -- Kullanıcı (Users.Id).
    [RoleId] uniqueidentifier NOT NULL,  -- Rol (Roles.Id).
    CONSTRAINT [PK_UserRoles] PRIMARY KEY ([UserId], [RoleId]),  -- PK: bu sütun(lar) satırı tek tanır
    CONSTRAINT [FK_UserRoles_Roles_RoleId] FOREIGN KEY ([RoleId]) REFERENCES [Roles] ([Id]) ON DELETE CASCADE,  -- FK: bağlı kayıt silinirse bu satır da silinir (CASCADE)
    CONSTRAINT [FK_UserRoles_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE  -- FK: bağlı kayıt silinirse bu satır da silinir (CASCADE)
);
CREATE INDEX [IX_UserRoles_RoleId] ON [UserRoles] ([RoleId]);   -- hızlı arama için indeks

-- ---------------------------------------------------------------------------------------------
-- TABLO ShipperProfiles: Yük Veren'e ait ek bilgiler. Kullanıcıyla BİRE BİR.
-- ---------------------------------------------------------------------------------------------
CREATE TABLE [ShipperProfiles] (
    [UserId] uniqueidentifier NOT NULL,  -- Kullanıcı numarası; aynı zamanda bu satırın anahtarı (kullanıcı başına tek profil).
    [CompanyName] nvarchar(200) NULL,  -- Firma adı (opsiyonel).
    [TaxNumber] nvarchar(20) NULL,  -- Vergi no (10) ya da TC kimlik no (11), opsiyonel.
    [TaxOffice] nvarchar(100) NULL,  -- Vergi dairesi (opsiyonel).
    [About] nvarchar(1000) NULL,  -- Kısa tanıtım (opsiyonel).
    [CityId] int NOT NULL,  -- Bulunduğu ilin plaka kodu (Cities.Id).
    CONSTRAINT [PK_ShipperProfiles] PRIMARY KEY ([UserId]),  -- PK: bu sütun(lar) satırı tek tanır
    CONSTRAINT [FK_ShipperProfiles_Cities_CityId] FOREIGN KEY ([CityId]) REFERENCES [Cities] ([Id]) ON DELETE NO ACTION,  -- FK: bağlı kayıt silinemez (olmayan kayda işaret edilemez)
    CONSTRAINT [FK_ShipperProfiles_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE  -- FK: bağlı kayıt silinirse bu satır da silinir (CASCADE)
);
CREATE INDEX [IX_ShipperProfiles_CityId] ON [ShipperProfiles] ([CityId]);   -- hızlı arama için indeks

-- ---------------------------------------------------------------------------------------------
-- TABLO CarrierProfiles: Taşımacı'ya ait ek bilgiler. Kullanıcıyla BİRE BİR.
-- ---------------------------------------------------------------------------------------------
CREATE TABLE [CarrierProfiles] (
    [UserId] uniqueidentifier NOT NULL,  -- Kullanıcı numarası; aynı zamanda bu satırın anahtarı.
    [About] nvarchar(1000) NULL,  -- Kısa tanıtım (opsiyonel).
    [HomeCityId] int NOT NULL,  -- Merkez ilin plaka kodu (Cities.Id).
    [AverageRating] decimal(3,2) NOT NULL,  -- Puan ortalaması 0-5 (ileride yorumlarla güncellenecek).
    [RatingCount] int NOT NULL,  -- Kaç kişi puan verdi.
    [CompletedJobCount] int NOT NULL,  -- Tamamlanan iş sayısı.
    [IsAvailable] bit NOT NULL,  -- Yeni iş alabilir mi? (varsayılan evet)
    CONSTRAINT [PK_CarrierProfiles] PRIMARY KEY ([UserId]),  -- PK: bu sütun(lar) satırı tek tanır
    CONSTRAINT [FK_CarrierProfiles_Cities_HomeCityId] FOREIGN KEY ([HomeCityId]) REFERENCES [Cities] ([Id]) ON DELETE NO ACTION,  -- FK: bağlı kayıt silinemez (olmayan kayda işaret edilemez)
    CONSTRAINT [FK_CarrierProfiles_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE  -- FK: bağlı kayıt silinirse bu satır da silinir (CASCADE)
);
CREATE INDEX [IX_CarrierProfiles_HomeCityId] ON [CarrierProfiles] ([HomeCityId]);   -- hızlı arama için indeks

-- ---------------------------------------------------------------------------------------------
-- TABLO CarrierServiceCities: Taşımacının çalıştığı iller. (Taşımacı, İl) çifti benzersiz.
-- ---------------------------------------------------------------------------------------------
CREATE TABLE [CarrierServiceCities] (
    [CarrierId] uniqueidentifier NOT NULL,  -- Taşımacı (CarrierProfiles.UserId).
    [CityId] int NOT NULL,  -- Çalıştığı ilin plaka kodu (Cities.Id).
    CONSTRAINT [PK_CarrierServiceCities] PRIMARY KEY ([CarrierId], [CityId]),  -- PK: bu sütun(lar) satırı tek tanır
    CONSTRAINT [FK_CarrierServiceCities_CarrierProfiles_CarrierId] FOREIGN KEY ([CarrierId]) REFERENCES [CarrierProfiles] ([UserId]) ON DELETE CASCADE,  -- FK: bağlı kayıt silinirse bu satır da silinir (CASCADE)
    CONSTRAINT [FK_CarrierServiceCities_Cities_CityId] FOREIGN KEY ([CityId]) REFERENCES [Cities] ([Id]) ON DELETE NO ACTION  -- FK: bağlı kayıt silinemez (olmayan kayda işaret edilemez)
);
CREATE INDEX [IX_CarrierServiceCities_CityId] ON [CarrierServiceCities] ([CityId]);   -- hızlı arama için indeks

-- ---------------------------------------------------------------------------------------------
-- TABLO Vehicles: Taşımacının araçları. Bir taşımacının birden çok aracı olabilir.
-- ---------------------------------------------------------------------------------------------
CREATE TABLE [Vehicles] (
    [Id] uniqueidentifier NOT NULL,  -- Araç numarası (GUID).
    [CarrierId] uniqueidentifier NOT NULL,  -- Sahibi taşımacı (CarrierProfiles.UserId).
    [VehicleType] int NOT NULL,  -- 1=Tır, 2=Kamyon, 3=Kamyonet, 4=Frigorifik, 99=Diğer.
    [PlateNumber] nvarchar(20) NULL,  -- Plaka (opsiyonel).
    [CapacityKg] int NOT NULL,  -- Taşıma kapasitesi, kg.
    [CapacityVolume] decimal(9,2) NULL,  -- Hacim kapasitesi, m³ (opsiyonel).
    [CreatedAt] datetime2 NOT NULL,  -- Oluşturulma zamanı (UTC).
    [UpdatedAt] datetime2 NULL,  -- Son değişiklik (UTC).
    [IsDeleted] bit NOT NULL,  -- Yumuşak silme: 1 ise kayıt silinmiş sayılır, sorgularda görünmez.
    [RowVersion] rowversion NOT NULL,  -- SQL Server'ın otomatik sürüm damgası: eşzamanlı çakışmayı yakalar.
    CONSTRAINT [PK_Vehicles] PRIMARY KEY ([Id]),  -- PK: bu sütun(lar) satırı tek tanır
    CONSTRAINT [FK_Vehicles_CarrierProfiles_CarrierId] FOREIGN KEY ([CarrierId]) REFERENCES [CarrierProfiles] ([UserId]) ON DELETE CASCADE  -- FK: bağlı kayıt silinirse bu satır da silinir (CASCADE)
);
CREATE INDEX [IX_Vehicles_CarrierId] ON [Vehicles] ([CarrierId]);   -- hızlı arama için indeks

-- ---------------------------------------------------------------------------------------------
-- TABLO RefreshTokens: Oturum yenileme jetonları. Jetonun kendisi değil, yalnız HASH'i saklanır.
-- ---------------------------------------------------------------------------------------------
CREATE TABLE [RefreshTokens] (
    [Id] uniqueidentifier NOT NULL,  -- Jeton kaydı numarası (GUID).
    [UserId] uniqueidentifier NOT NULL,  -- Sahibi kullanıcı (Users.Id).
    [TokenHash] nvarchar(64) NOT NULL,  -- Jetonun SHA-256 hash'i. Benzersiz. Veritabanı sızsa bile jeton kullanılamaz.
    [DeviceId] nvarchar(100) NOT NULL,  -- Jetonun verildiği cihaz.
    [ExpiresAt] datetime2 NOT NULL,  -- Geçerlilik bitişi (UTC).
    [RevokedAt] datetime2 NULL,  -- İptal edildiyse zamanı.
    [ReplacedByTokenId] uniqueidentifier NULL,  -- Yenilemede yerine geçen yeni jeton (rotasyon zinciri).
    [CreatedAt] datetime2 NOT NULL,  -- Oluşturulma (UTC).
    [UpdatedAt] datetime2 NULL,  -- Son değişiklik (UTC).
    [IsDeleted] bit NOT NULL,  -- Yumuşak silme işareti.
    [RowVersion] rowversion NOT NULL,  -- Eşzamanlılık damgası (çift yenilemeyi yakalar).
    CONSTRAINT [PK_RefreshTokens] PRIMARY KEY ([Id]),  -- PK: bu sütun(lar) satırı tek tanır
    CONSTRAINT [FK_RefreshTokens_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE  -- FK: bağlı kayıt silinirse bu satır da silinir (CASCADE)
);
CREATE UNIQUE INDEX [IX_RefreshTokens_TokenHash] ON [RefreshTokens] ([TokenHash]);   -- UNIQUE: tekrar edemez
CREATE INDEX [IX_RefreshTokens_UserId] ON [RefreshTokens] ([UserId]);   -- hızlı arama için indeks

