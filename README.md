# 🎓 A2K26 THPT QUế Lâm - Website Kỷ Niệm Lớp 10A2‑K26

**Website Lớp 10A2‑K26 THPT Quế Lâm** — Nơi lưu giữ kỷ niệm tuổi học trò.

[![Netlify Status](https://api.netlify.com/api/v1/badges/75dee73a-5212-44da-be1d-03caa70b78c4/deploy-status)](https://app.netlify.com/sites/a2k26thptquelam/deploys)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Node Version](https://img.shields.io/badge/node-18.x-green.svg)](package.json)

## 🌟 Giới thiệu dự án

A2K26THPTQUELAM là website kỷ niệm được phát triển dành riêng cho tập thể lớp 10A2‑K26 (THPT Quế Lâm), nơi lưu giữ hình ảnh, thông tin chi tiết về từng thành viên và những khoảnh khắc đáng nhớ của thời học sinh. Website được xây dựng với giao diện hiện đại, thân thiện, an toàn và tối ưu cho mọi thiết bị (mobile, tablet, desktop).

## ✅ Tính năng nổi bật

* 🖼️ **Thư viện ảnh kỷ niệm**: Upload, xem, tìm kiếm và sắp xếp ảnh theo bộ nhớ/sự kiện với giao diện grid hiện đại.
* 👥 **Danh sách học sinh chi tiết**: Hiển thị đầy đủ 45 thành viên với vai trò (lớp trưởng, bí thư, tổ trưởng v.v.) và liên hệ.
* 🔐 **Bảo vệ bằng mật khẩu**: Kiểm soát quyền truy cập và upload ảnh, đảm bảo an toàn dữ liệu.
* 📱 **Responsive Design**: Tối ưu trải nghiệm trên mobile, tablet & desktop với CSS Tailwind.
* ⚡ **Upload ảnh kèm progress bar**: Phản hồi theo thời gian thực, hỗ trợ đa file.
* 🔍 **Tìm kiếm & lọc ảnh**: Tìm kiếm nhanh chóng theo tên, ngày, hoặc từ khóa.
* 📊 **Quản lý điểm số & khảo sát**: Lưu trữ và cập nhật dữ liệu điểm số, kết quả khảo sát lớp.
* 💾 **Cache thông minh**: Lưu trữ ảnh cục bộ để tải nhanh hơn lần kế tiếp.
* 🌐 **PWA Support**: Tính năng Progressive Web App cho trải nghiệm app-like.

## 🛠️ Công nghệ sử dụng

| Loại | Công nghệ |
|------|-----------|
| **Frontend** | HTML5, CSS3, JavaScript (Vanilla) |
| **Styling** | Tailwind CSS v3.x |
| **Backend** | Netlify Functions (Node.js 18.x) |
| **API** | GitHub REST API (@octokit/rest) |
| **Storage** | GitHub Repository (Images & Data) |
| **Hosting** | Netlify |
| **PWA** | Service Workers, manifest.json |
| **Caching** | HTTP Cache Headers, Browser Cache |

## 🚀 Hướng dẫn cài đặt & Deploy

### Yêu cầu hệ thống

- **Node.js**: v18.x hoặc cao hơn
- **npm**: v8.x hoặc cao hơn
- **Git**: Để clone repository
- **GitHub Account**: Để tạo Personal Access Token
- **Netlify Account**: Để deploy & quản lý functions

### Bước 1: Tạo GitHub Personal Access Token

1. Đăng nhập vào [GitHub](https://github.com)
2. Vào **Settings** → **Developer settings** → **Personal access tokens**
3. Click **Generate new token (classic)**
4. Chọn scopes: `repo` (hoặc `public_repo` nếu public)
5. Copy token, lưu vào nơi an toàn

### Bước 2: Clone & Setup Repository

```bash
# Clone repository
git clone https://github.com/your-username/testweb.git
cd testweb

# Cài đặt dependencies
npm install
```

### Bước 3: Kết nối Netlify

```bash
# Đăng nhập Netlify
npm install -g netlify-cli
netlify login

# Liên kết project
netlify link
```

### Bước 4: Thiết lập Biến Môi Trường

Tạo file `.env.production` trong root directory:

```env
# Mật khẩu bảo vệ lớp
CLASS_PASSWORD=your-class-password-here

# Thông tin GitHub
GITHUB_USER=your-github-username
GITHUB_REPO=your-repo-name
GITHUB_TOKEN=your-personal-access-token
GITHUB_BRANCH=main

# Tùy chọn
API_TIMEOUT=30000
MAX_IMAGE_SIZE=5242880
```

Hoặc trên Netlify UI:
1. Vào **Site settings** → **Build & deploy** → **Environment**
2. Thêm từng biến môi trường

### Bước 5: Deploy

```bash
# Deploy to Netlify
netlify deploy --prod

# Hoặc push lên GitHub, Netlify sẽ tự động deploy
git add .
git commit -m "Initial setup"
git push origin main
```

## 📁 Cấu trúc thư mục

```
A2-K26-THPT-QUELAM/
├── index.html              # Trang chính
├── style.css               # CSS chính (production)
├── style.min.css           # CSS minified
├── main.js                 # Logic JavaScript chính (production)
├── main.min.js             # JavaScript minified
├── sw.js                   # Service Worker (PWA)
├── manifest.json           # PWA Manifest
├── netlify.toml            # Cấu hình Netlify & Build rules
├── package.json            # Dependencies & Scripts
├── README.md               # Tài liệu này
├── functions/              # Netlify Functions (Backend)
│   ├── auth-check.js       # Xác thực mật khẩu
│   ├── upload-image.js     # Upload ảnh
│   ├── upload-scores.js    # Upload điểm số
│   ├── upload-survey-scores.js
│   ├── upload-tkb.js       # Upload file TKB
│   ├── get-memories.js     # Lấy danh sách ảnh
│   ├── get-scores.js       # Lấy điểm số
│   ├── get-survey-scores.js
│   ├── get-tkb-files.js    # Lấy file TKB
│   ├── delete-image.js     # Xóa ảnh
│   ├── delete-scores.js    # Xóa điểm số
│   ├── delete-survey-scores.js
│   ├── delete-tkb.js       # Xóa file TKB
│   ├── update-image-metadata.js
│   └── cache-helper.js     # Hỗ trợ caching
├── data/                   # Data JSON (lưu trữ)
│   ├── memories.json       # Metadata ảnh
│   └── tkb.json            # Dữ liệu TKB
└── img/                    # Thư mục lưu ảnh kỷ niệm
```

## 📖 Hướng dẫn sử dụng

### Cho Học Sinh

1. **Truy cập website**: Vào [A2K26 THPT Quế Lâm](https://a2k26thptquelam.netlify.app)
2. **Nhập mật khẩu lớp**: Để xem toàn bộ nội dung
3. **Xem ảnh kỷ niệm**: 
   - Scroll xem grid ảnh
   - Click ảnh để xem full size
   - Sử dụng tìm kiếm để tìm ảnh cụ thể
4. **Upload ảnh** (nếu được phép):
   - Click "Upload Ảnh"
   - Chọn ảnh từ thiết bị
   - Thêm mô tả (tùy chọn)
   - Click "Tải lên"

### Cho Quản Trị

#### Upload Ảnh
```javascript
// Endpoint: POST /api/upload-image
// Yêu cầu: 
// - file: FormData binary
// - description: string
// - password: string
// Response: { success: true, filename: string }
```

#### Upload Điểm Số
```javascript
// Endpoint: POST /api/upload-scores
// Body: JSON object chứa dữ liệu điểm
```

#### Quản lý Mật Khẩu
- Thay đổi `CLASS_PASSWORD` trong biến môi trường Netlify
- Cập nhật sẽ có hiệu lực sau build tiếp theo

## 🐞 Xử lý lỗi thường gặp

### ❌ Không upload được ảnh

**Nguyên nhân & Giải pháp:**
- ✅ Kiểm tra GitHub Token có đúng & không hết hạn
- ✅ Đảm bảo biến môi trường đã cấu hình đúng (check Netlify UI)
- ✅ Dung lượng ảnh không vượt quá 5MB
- ✅ Kiểm tra tên repo & branch đúng trong `.env`
- ✅ Xem logs: Netlify → Functions → check errors

### ❌ Không hiển thị ảnh

**Nguyên nhân & Giải pháp:**
- ✅ Kiểm tra kết nối mạng
- ✅ Kiểm tra quyền truy cập repo (công khai hoặc có quyền)
- ✅ Xóa cache browser: **Ctrl+Shift+Delete**
- ✅ Kiểm tra console browser (**F12**) xem có lỗi gì

### ❌ Mật khẩu không hoạt động

- ✅ Kiểm tra đã set biến `CLASS_PASSWORD` chưa
- ✅ Đợi Netlify rebuild (có thể mất 1-2 phút)
- ✅ Hard refresh: **Ctrl+F5**

### ❌ Lỗi CORS

- ✅ Kiểm tra Netlify functions headers đúng không
- ✅ Xem file `netlify.toml` có cấu hình headers chưa

## 💡 Định hướng phát triển

- ✨ Timeline kỷ niệm theo năm học / tháng
- ✨ Trang hồ sơ riêng cho từng thành viên (với liên hệ)
- ✨ Hệ thống bình luận, like, share ảnh
- ✨ Album tổ chức (theo sự kiện, thời gian)
- ✨ Export dữ liệu (PDF, ZIP)
- ✨ Thông báo & email cho thành viên khi có ảnh mới
- ✨ Dark mode
- ✨ Multilanguage support

## 🔒 Bảo mật

- ✅ Mật khẩu được hash trên server
- ✅ HTTPS bắt buộc (Netlify)
- ✅ CORS headers được cấu hình
- ✅ Input sanitization để chống XSS
- ✅ Rate limiting cho upload
- ✅ GitHub token được lưu riêng (environment variable)

## 📊 Performance

- ✅ CSS & JS minified
- ✅ HTTP caching headers (1 năm cho ảnh)
- ✅ Service Worker caching
- ✅ Lazy loading ảnh
- ✅ CDN via Netlify
- ✅ Lighthouse score: 90+

## 🤝 Đóng góp

Muốn cải thiện dự án? Hãy:

1. Fork repository
2. Tạo branch mới: `git checkout -b feature/tên-tính-năng`
3. Commit thay đổi: `git commit -am 'Thêm tính năng mới'`
4. Push: `git push origin feature/tên-tính-năng`
5. Tạo Pull Request

## 📞 Liên hệ & Hỗ trợ

| Thông tin | Chi tiết |
|-----------|---------|
| **Developer** | Lê Trung Kiên |
| **Email** | [letrungkien2k10phutho@gmail.com](mailto:letrungkien2k10phutho@gmail.com) |
| **GitHub** | [github.com/jayetcixgaming2010](https://github.com/jayetcixgaming2010) |
| **Website** | [a2k26thptquelam.netlify.app](https://a2k26thptquelam.netlify.app) |
| **Issues** | [Report bug](letrungkienprofiles.netlify.app) |

## 📄 License

MIT License © 2025 A2K26 - A2-k26 THPT Quế Lâm

Bạn có quyền sử dụng, sửa đổi và phân phối code này, với điều kiện ghi nhận tác giả.
<p align="center">
  <strong>Made with ❤️ by Lê Trung Kiên</strong>
</p>

<p align="center">
  <img src="https://github.com/Kiendzzz/testweb/blob/main/anhlop.png" alt="Ảnh tập thể lớp A2K26" width="600"/>
</p>

---

**Last Updated**: November 2025

