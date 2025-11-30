// Đảm bảo DOM đã sẵn sàng trước khi thực hiện các tác vụ
// These are now initialized in DOMContentLoaded
// Authentication state
let isAuthenticated = false;
let classPassword = null; // populated after server-side auth
let pendingUploadAction = null; // 'image' or 'tkb' when awaiting password

// Rate limiting for uploads
let lastUploadTime = 0;
const UPLOAD_COOLDOWN = 5000; // 5 seconds between uploads

// Pagination and filter state for memories
let currentPage = 1;
let filteredMemories = [];
let allMemoryElements = []; // Original list of DOM elements for filter/sort
const itemsPerPage = 20;

// No results div for memories
let noResultsDiv = null;

// Safe loading state toggler to avoid runtime errors
function showLoadingState(isLoading) {
    try {
        const skeleton = document.getElementById('memorySkeleton');
        const grid = document.querySelector('.memory-grid');
        if (skeleton) skeleton.classList.toggle('hidden', !isLoading);
        if (grid && isLoading) grid.style.opacity = '0.6';
        if (grid && !isLoading) grid.style.opacity = '1';
    } catch (_) {}
}

// Input sanitization function
function sanitizeInput(input) {
    return input.trim().replace(/[<>]/g, '');
}

// XSS protection for user inputs
function escapeHtml(text) {
    const map = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
    };
    return text.replace(/[&<>"']/g, function(m) { return map[m]; });
}

// Modal & focus helpers
const __modalState = { active: false, lastFocused: null, keyHandler: null, scrollTop: 0 };

function lockBodyScroll() {
    if (__modalState.active) return;
    __modalState.scrollTop = window.scrollY || document.documentElement.scrollTop || 0;
    document.body.style.position = 'fixed';
    document.body.style.top = `-${__modalState.scrollTop}px`;
    document.body.style.left = '0';
    document.body.style.right = '0';
    __modalState.active = true;
}

function unlockBodyScroll() {
    if (!__modalState.active) return;
    document.body.style.position = '';
    document.body.style.top = '';
    document.body.style.left = '';
    document.body.style.right = '';
    window.scrollTo(0, __modalState.scrollTop || 0);
    __modalState.active = false;
}

function trapFocus(modal) {
    if (!modal) return;
    __modalState.lastFocused = document.activeElement;
    const focusable = modal.querySelectorAll('a[href], area[href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), button:not([disabled]), [tabindex]:not([tabindex="-1"])');
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    if (first && typeof first.focus === 'function') first.focus();

    __modalState.keyHandler = function(e) {
        if (e.key === 'Tab') {
            if (focusable.length === 0) {
                e.preventDefault();
                return;
            }
            if (e.shiftKey) {
                if (document.activeElement === first) {
                    e.preventDefault();
                    last.focus();
                }
            } else {
                if (document.activeElement === last) {
                    e.preventDefault();
                    first.focus();
                }
            }
        }
    };
    document.addEventListener('keydown', __modalState.keyHandler);
}

function releaseFocusTrap() {
    if (__modalState.keyHandler) {
        document.removeEventListener('keydown', __modalState.keyHandler);
        __modalState.keyHandler = null;
    }
    try { if (__modalState.lastFocused && typeof __modalState.lastFocused.focus === 'function') __modalState.lastFocused.focus(); } catch(e){}
    __modalState.lastFocused = null;
}

// Close visible modals when Escape is pressed
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        const modals = ['studentModal','imageModal','uploadModal','passwordModal','editModal','scoreUploadModal','tkbUploadModal'];
        for (const id of modals) {
            const el = document.getElementById(id);
            if (el && !el.classList.contains('hidden')) {
                el.classList.add('hidden');
                el.classList.remove('show');
                releaseFocusTrap();
                unlockBodyScroll();
                break;
            }
        }
    }
});

// Check if user can upload (rate limiting)
function canUpload() {
    const now = Date.now();
    if (now - lastUploadTime < UPLOAD_COOLDOWN) {
        const remainingTime = Math.ceil((UPLOAD_COOLDOWN - (now - lastUploadTime)) / 1000);
        showErrorToast(`Vui lòng đợi ${remainingTime} giây trước khi upload tiếp!`);
        return false;
    }
    return true;
}

// Image lazy loading with intersection observer
function setupLazyLoading() {
    const images = document.querySelectorAll('img[loading="lazy"]');
    
    if ('IntersectionObserver' in window) {
        const imageObserver = new IntersectionObserver((entries, observer) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    const img = entry.target;
                    img.classList.add('fade-in');
                    observer.unobserve(img);
                }
            });
        }, {
            rootMargin: '50px 0px',
            threshold: 0.1
        });

        images.forEach(img => imageObserver.observe(img));
    }
}

// Create no results div
function createNoResultsDiv() {
    noResultsDiv = document.createElement('div');
    noResultsDiv.className = 'col-span-full text-center py-12';
    noResultsDiv.innerHTML = `
        <i data-feather="image" class="w-16 h-16 mx-auto text-gray-400 mb-4"></i>
        <h3 class="text-xl font-semibold text-gray-600 mb-2">Không tìm thấy kết quả</h3>
        <p class="text-gray-500">Hãy thử từ khóa khác!</p>
    `;
    noResultsDiv.style.display = 'none';
    return noResultsDiv;
}

// Apply filter and sort, then paginate
function applyFilterAndSort() {
    const searchText = document.getElementById('searchMemory').value.toLowerCase();
    const sortValue = document.getElementById('sortMemory').value;

    // Filter on original allMemoryElements (DOM elements)
    let filtered = [...allMemoryElements].filter(mem => {
        const title = mem.querySelector('.memory-title').textContent.toLowerCase();
        return title.includes(searchText);
    });

    // Sort
    filtered.sort((a, b) => {
        if (sortValue === 'title') {
            return a.querySelector('.memory-title').textContent.localeCompare(
                b.querySelector('.memory-title').textContent);
        } else if (sortValue === 'newest') {
            return b.dataset.path.localeCompare(a.dataset.path);
        } else if (sortValue === 'oldest') {
            return a.dataset.path.localeCompare(b.dataset.path);
        }
        return 0;
    });

    filteredMemories = filtered;

    // Hide all elements
    allMemoryElements.forEach(el => el.style.display = 'none');

    // Handle no results
    if (filtered.length === 0) {
        if (!noResultsDiv) {
            const grid = document.querySelector('.memory-grid');
            grid.appendChild(createNoResultsDiv());
        }
        noResultsDiv.style.display = 'block';
        renderPagination(1); // Single "page" for no results
        return;
    } else {
        if (noResultsDiv) noResultsDiv.style.display = 'none';
    }

    // Show paginated
    const totalPages = Math.ceil(filtered.length / itemsPerPage) || 1;
    if (currentPage < 1) currentPage = 1;
    if (currentPage > totalPages) currentPage = totalPages;
    const start = (currentPage - 1) * itemsPerPage;
    const end = start + itemsPerPage;
    const paginated = filtered.slice(start, end);
    paginated.forEach((el, idx) => {
        el.classList.add('fade-in-up');
        el.style.animationDelay = `${idx * 0.05}s`;
        el.style.display = 'block';
    });

    renderPagination(totalPages);
}

// Render pagination
function renderPagination(totalPages) {
    const pagination = document.getElementById('pagination');
    if (!pagination) return;

    pagination.innerHTML = '';

    if (totalPages <= 1) return; // No pagination if <=1 page

    // Prev
    const prevBtn = document.createElement('button');
    prevBtn.textContent = 'Â«';
    prevBtn.className = `px-3 py-1 rounded ${currentPage === 1 ? 'bg-gray-300 cursor-not-allowed' : 'bg-purple-600 text-white hover:bg-purple-700'}`;
    prevBtn.disabled = currentPage === 1;
    prevBtn.onclick = () => {
        if (currentPage > 1) {
            currentPage--;
            applyFilterAndSort(); // Re-apply to show new page
        }
    };
    pagination.appendChild(prevBtn);

    // Numbers
    for (let i = 1; i <= totalPages; i++) {
        const button = document.createElement('button');
        button.textContent = i;
        button.className = `px-3 py-1 rounded ${i === currentPage ? 'bg-purple-600 text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'}`;
        button.onclick = () => {
            currentPage = i;
            applyFilterAndSort();
        };
        pagination.appendChild(button);
    }

    // Next
    const nextBtn = document.createElement('button');
    nextBtn.textContent = 'Â»';
    nextBtn.className = `px-3 py-1 rounded ${currentPage === totalPages ? 'bg-gray-300 cursor-not-allowed' : 'bg-purple-600 text-white hover:bg-purple-700'}`;
    nextBtn.disabled = currentPage === totalPages;
    nextBtn.onclick = () => {
        if (currentPage < totalPages) {
            currentPage++;
            applyFilterAndSort();
        }
    };
    pagination.appendChild(nextBtn);
}

// Debounce function
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Check authentication from localStorage on page load
document.addEventListener('DOMContentLoaded', function() {

    const authStatus = localStorage.getItem('isAuthenticated');
    isAuthenticated = authStatus === 'true';
    classPassword = localStorage.getItem('classPassword') || null;
    
    if (isAuthenticated) {
        showMemoryActions();
        updateUploadButtonUI();
    }
    
    // Setup lazy loading
    setupLazyLoading();
    
    // Load memories after DOM is ready (shorter on mobile)
    setTimeout(() => {
        loadMemories();
    }, mobileDelay(100));

    // Event listeners for search and sort
    const searchInput = document.getElementById('searchMemory');
    const sortSelect = document.getElementById('sortMemory');
    const debouncedFilter = debounce(() => { currentPage = 1; applyFilterAndSort(); }, 300);
    searchInput.addEventListener('input', debouncedFilter);
    sortSelect.addEventListener('change', () => { currentPage = 1; applyFilterAndSort(); });
});

// Load memories from server
async function loadMemories() {
    try {
        showLoadingState(true);
        
        // Add cache busting to force fresh data from server
        const cacheParam = '?cache=' + Date.now();
        const resp = await fetch('/.netlify/functions/get-memories' + cacheParam);
        if (!resp.ok) {
            const errorData = await resp.json().catch(() => ({ error: 'Unknown error' }));
            throw new Error(errorData.error || `HTTP ${resp.status}: Failed to load memories`);
        }

        const responseData = await resp.json();
        const { data: memories, total } = responseData || {};
        
        // Validate response data
        if (!Array.isArray(memories)) {
            throw new Error('Invalid response format from server');
        }

        const grid = document.querySelector('.memory-grid');
        grid.innerHTML = '';

        if (memories.length === 0) {
            grid.appendChild(createNoResultsDiv());
            noResultsDiv.innerHTML = `
                <i data-feather="image" class="w-16 h-16 mx-auto text-gray-400 mb-4"></i>
                <h3 class="text-xl font-semibold text-gray-600 mb-2">Chưa có ảnh kỷ niệm</h3>
                <p class="text-gray-500">Hãy upload ảnh đầu tiên để bắt đầu!</p>
            `;
            noResultsDiv.style.display = 'block';
            feather.replace();
            return;
        }

        // Create all DOM elements
        allMemoryElements = [];
        memories.forEach(mem => {
            const memoryCard = document.createElement('div');
            memoryCard.className = 'memory-card';
            memoryCard.dataset.path = mem.path;
            memoryCard.dataset.title = mem.title;
            memoryCard.dataset.date = mem.date;
            memoryCard.style.display = 'none'; // Initially hidden
            
            // Add cache busting to image URL to force fresh load
            const imageUrl = mem.url + (mem.url.includes('?') ? '&' : '?') + 't=' + Date.now();
            
            // Keep original behavior; no extra AOS attributes added here
            memoryCard.innerHTML = `
                <img src="${imageUrl}" alt="${mem.title}" class="memory-img" loading="lazy">
                <div class="memory-overlay">
                    <h3 class="memory-title">${escapeHtml(mem.title)}</h3>
                    <p class="memory-date">${new Date(mem.date).toLocaleDateString('vi-VN')}</p>
                </div>
                <div class="memory-actions" style="display: ${isAuthenticated ? 'flex' : 'none'};">
                    <div class="memory-action-btn edit-btn"><i data-feather="edit"></i></div>
                    <div class="memory-action-btn delete-btn"><i data-feather="trash-2"></i></div>
                </div>
            `;
            const imgEl = memoryCard.querySelector('.memory-img');
            if (imgEl) imgEl.onclick = () => openImageModal(imageUrl);
            // fallback: open when clicking anywhere on card except actions
            memoryCard.addEventListener('click', (evt) => {
                if (evt.target.closest('.memory-action-btn')) return;
                if (evt.target.closest('.memory-actions')) return;
                openImageModal(imageUrl);
            });
            grid.appendChild(memoryCard);
            allMemoryElements.push(memoryCard);
        });

        feather.replace();

        // Initial filter/sort/paginate
        currentPage = 1;
        applyFilterAndSort();

        // Keep original AOS init/behavior managed in index.html script

    } catch (err) {
        console.error('Load memories error:', err);
        
        // Show fallback content for network errors
        const grid = document.querySelector('.memory-grid');
        grid.innerHTML = `
            <div class="col-span-full text-center py-12">
                <i data-feather="alert-triangle" class="w-16 h-16 mx-auto text-red-400 mb-4"></i>
                <h3 class="text-xl font-semibold text-red-600 mb-2">Lỗi tải dữ liệu</h3>
                <p class="text-gray-500">Kiểm tra kết nối và thử lại!</p>
            </div>
        `;
        feather.replace();
    } finally {
        showLoadingState(false);
        // Hiện nội dung web khi dữ liệu đã render xong
        window.showMainContent && window.showMainContent();
    }
}

function updateUploadButtonUI() {
    const uploadBtn = document.getElementById('uploadBtn');
    const mobileUploadBtn = document.getElementById('mobileUploadBtn');
    const uploadTKBBtn = document.getElementById('uploadTKBBtn');

    // Desktop: show the topbar upload button only on non-mobile viewports.
    if (uploadBtn) {
        // keep the button behavior bound, but only make it visible when not on mobile
        uploadBtn.onclick = isAuthenticated ? openUploadModal : openPasswordModal;
        uploadBtn.innerHTML = isAuthenticated ? '<i data-feather="upload" class="mr-2"></i> Upload ảnh' : '<i data-feather="lock" class="mr-2"></i> Nhập mật khẩu';
        if (!isMobile()) {
            uploadBtn.style.display = 'inline-flex';
        } else {
            // On small screens the topbar upload button must remain hidden so the
            // upload action stays inside the three-dot mobile menu.
            uploadBtn.style.display = '';
        }
    }

    // Mobile: the upload control inside the mobile menu should be the one used on small screens
    if (mobileUploadBtn) {
        mobileUploadBtn.onclick = isAuthenticated ? openUploadModal : openPasswordModal;
        mobileUploadBtn.innerHTML = isAuthenticated ? '<i data-feather="upload" class="mr-2"></i> Upload ảnh' : '<i data-feather="lock" class="mr-2"></i> Nhập mật khẩu';
        // keep it visible in the mobile menu; its parent menu controls overall visibility
        mobileUploadBtn.style.display = 'inline-flex';
    }

    // Debugging help: log current device and auth state (useful for QA)
    try {
        console.debug('[updateUploadButtonUI] isMobile:', isMobile(), 'isAuthenticated:', !!isAuthenticated);
    } catch (e) {}

    // TKB Upload: visible but will prompt for password when needed
    if (uploadTKBBtn) uploadTKBBtn.style.display = 'inline-block';

    feather.replace();
}

function openPasswordModal() {
    if (isAuthenticated) {
        openUploadModal();
    } else {
        const modal = document.getElementById('passwordModal');
        if (modal) {
            modal.classList.remove('hidden');
            modal.setAttribute('tabindex', '-1');
            modal.setAttribute('aria-hidden', 'false');
            lockBodyScroll();
            trapFocus(modal);
        }
    }
}

function closePasswordModal() {
    const modal = document.getElementById('passwordModal');
    if (modal) {
        modal.classList.add('hidden');
        modal.setAttribute('aria-hidden', 'true');
    }
    document.getElementById('passwordError').classList.add('hidden');
    document.getElementById('passwordInput').value = '';
    releaseFocusTrap();
    unlockBodyScroll();
}

async function checkPassword() {
    const enteredPassword = document.getElementById('passwordInput').value;
    const errorElement = document.getElementById('passwordError');
    try {
        const resp = await fetch('/.netlify/functions/auth-check', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ password: enteredPassword })
        });
        if (!resp.ok) {
            let msg = 'Xác thực thất bại.';
            try { const data = await resp.json(); if (data?.error) msg = data.error; } catch(_) {}
            if (resp.status === 404) msg = 'Không tìm thấy function auth-check. Hãy deploy lên Netlify.';
            if (resp.status === 500) msg = 'Máy chủ chưa cấu hình CLASS_PASSWORD.';
            throw new Error(msg);
        }
        isAuthenticated = true;
        classPassword = enteredPassword;
        // Persist auth permanently (one-time entry)
        localStorage.setItem('isAuthenticated', 'true');
        localStorage.setItem('classPassword', classPassword);
        closePasswordModal();
        showMemoryActions();
        updateUploadButtonUI();
        loadMemories();
        showSuccessToast('Đăng nhập thành công!');

        // If user attempted an action before auth, execute it now
        if (pendingUploadAction === 'image') {
            // openUploadModal checks isAuthenticated and will open
            openUploadModal();
        } else if (pendingUploadAction === 'tkb') {
            // openTKBUploadModal will respect auth
            openTKBUploadModal();
        } else if (pendingUploadAction === 'score') {
            // openScoreUploadModal will respect auth
            openScoreUploadModal();
        }
        pendingUploadAction = null;
    } catch (e) {
        errorElement.textContent = e.message || 'Mật khẩu không đúng. Vui lòng thử lại.';
        errorElement.classList.remove('hidden');
        const input = document.getElementById('passwordInput');
        input.value = '';
        input.focus();
    }
}

// Upload modal functions
function openUploadModal() {
    // If not authenticated, request password first and remember intent
    if (!isAuthenticated) {
        pendingUploadAction = 'image';
        openPasswordModal();
        return;
    }
    const modal = document.getElementById('uploadModal');
    if (modal) {
        modal.classList.remove('hidden');
        modal.setAttribute('tabindex', '-1');
        modal.setAttribute('aria-hidden', 'false');
        lockBodyScroll();
        trapFocus(modal);
    }
}

function closeUploadModal() {
    const modal = document.getElementById('uploadModal');
    if (modal) {
        modal.classList.add('hidden');
        modal.setAttribute('aria-hidden', 'true');
    }
    document.getElementById('uploadForm').reset();
    document.getElementById('fileName').classList.add('hidden');
    releaseFocusTrap();
    unlockBodyScroll();
}

// Save edit metadata
async function saveEdit() {
    const path = document.getElementById('editPath').value;
    const title = sanitizeInput(document.getElementById('editTitle').value);
    const date = document.getElementById('editDate').value;
    if (!title || title.length < 3) { showErrorToast('Tiêu đề phải có ít nhất 3 ký tự!'); return; }
    if (!date) { showErrorToast('Vui lòng chọn ngày chụp!'); return; }
    try {
        const resp = await fetch('/.netlify/functions/update-image-metadata', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ path, title, date, password: classPassword })
        });
        if (!resp.ok) throw new Error('Cập nhật thất bại');
        showSuccessToast('Đã cập nhật thông tin ảnh!');
        const editModal = document.getElementById('editModal');
        if (editModal) {
            editModal.classList.add('hidden');
            editModal.setAttribute('aria-hidden', 'true');
        }
        releaseFocusTrap();
        unlockBodyScroll();
        loadMemories();
    } catch (e) {
        showErrorToast('Lỗi khi cập nhật!');
    }
}

function closeEditModal() {
    const modal = document.getElementById('editModal');
    if (modal) {
        modal.classList.add('hidden');
        modal.setAttribute('aria-hidden', 'true');
    }
    releaseFocusTrap();
    unlockBodyScroll();
}

// File input display + validate size
document.getElementById('imageFile').addEventListener('change', function(e) {
    const fileNameElement = document.getElementById('fileName');
    if (this.files.length > 0) {
        const file = this.files[0];
        if (file.size > 5 * 1024 * 1024) { // 5MB limit
            alert("⚠️ Ảnh vượt quá 5MB. Vui lòng chọn file nhỏ hơn.");
            this.value = ""; // reset input
            fileNameElement.classList.add('hidden');
            return;
        }
        fileNameElement.textContent = file.name + ` (${(file.size/1024/1024).toFixed(2)} MB)`;
        fileNameElement.classList.remove('hidden');
    } else {
        fileNameElement.classList.add('hidden');
    }
});

// ================== UPLOAD IMAGE ==================
// Helper: Compress image before upload
async function compressImage(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = (e) => {
            const img = new Image();
            img.onload = () => {
                const canvas = document.createElement('canvas');
                // Calculate new dimensions (max 1920x1440)
                const MAX_WIDTH = 1920;
                const MAX_HEIGHT = 1440;
                let width = img.width;
                let height = img.height;
                
                if (width > height) {
                    if (width > MAX_WIDTH) {
                        height *= MAX_WIDTH / width;
                        width = MAX_WIDTH;
                    }
                } else {
                    if (height > MAX_HEIGHT) {
                        width *= MAX_HEIGHT / height;
                        height = MAX_HEIGHT;
                    }
                }
                
                canvas.width = width;
                canvas.height = height;
                const ctx = canvas.getContext('2d');
                ctx.drawImage(img, 0, 0, width, height);
                
                // Convert to compressed base64 (quality 0.75 for good balance)
                const base64 = canvas.toDataURL('image/jpeg', 0.75).split(',')[1];
                resolve(base64);
            };
            img.onerror = () => reject(new Error('Failed to load image'));
            img.src = e.target.result;
        };
        reader.onerror = () => reject(new Error('Failed to read file'));
        reader.readAsDataURL(file);
    });
}

function uploadImage() {
    // Rate limiting check
    if (!canUpload()) {
        return;
    }

    const title = sanitizeInput(document.getElementById('imageTitle').value);
    const date = document.getElementById('imageDate').value;
    const file = document.getElementById('imageFile').files[0];

    // Enhanced validation
    if (!title || title.length < 3) {
        showErrorToast('Tiêu đề phải có ít nhất 3 ký tự!');
        return;
    }

    if (!date) {
        showErrorToast('Vui lòng chọn ngày chụp!');
        return;
    }

    if (!file) {
        showErrorToast('Vui lòng chọn ảnh!');
        return;
    }

    // File type validation
    const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    if (!allowedTypes.includes(file.type)) {
        showErrorToast('Chỉ chấp nhận file JPG, PNG, WebP!');
        return;
    }

    // File size validation (5MB)
    if (file.size > 5 * 1024 * 1024) {
        showErrorToast('Kích thước file không được vượt quá 5MB!');
        return;
    }

    // Show loading state with progress bar
    const uploadBtn = document.querySelector('#uploadForm button[type="button"]');
    const uploadProgress = document.getElementById('uploadProgress');
    const progressBar = document.getElementById('progressBar');
    const progressText = document.getElementById('progressText');
    
    const originalText = uploadBtn.innerHTML;
    uploadBtn.innerHTML = '<div class="inline-block animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>Đang upload...';
    uploadBtn.disabled = true;
    uploadProgress.classList.remove('hidden');
    
    // Progressive progress: 0-40% for compression, 40-100% for upload
    let progress = 0;
    const progressInterval = setInterval(() => {
        progress += Math.random() * 8;
        if (progress > 95) progress = 95;
        progressBar.style.width = progress + '%';
        progressText.textContent = `Đang upload... ${Math.round(progress)}%`;
    }, 150);

    // Compress image in parallel
    compressImage(file).then(async (base64) => {
        try {
            // Update progress to 50% after compression
            progress = 50;
            progressBar.style.width = progress + '%';
            
            const resp = await fetch('/.netlify/functions/upload-image', {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    title,
                    date,
                    filename: file.name,
                    contentBase64: base64,
                    password: classPassword,
                }),
            });
            
            clearInterval(progressInterval);
            progressBar.style.width = '100%';
            progressText.textContent = 'Hoàn tất...';

            if (!resp.ok) {
                const errorData = await resp.json().catch(() => ({ error: 'Unknown error' }));
                throw new Error(errorData.error || `HTTP ${resp.status}: Upload failed`);
            }

            const data = await resp.json();
            showSuccessToast(`Upload thành công: ${data.path}`);
            
            // Force cache busting - add timestamp to image URL
            if (data.url) {
                data.url = data.url + '?t=' + Date.now();
            }
            
            closeUploadModal();
            
            // Reload memories after a short delay to ensure server is updated (shorter on mobile)
            setTimeout(() => {
                loadMemories();
            }, mobileDelay(800));
            
            lastUploadTime = Date.now();

        } catch (err) {
            console.error('Upload error:', err);
            showErrorToast(`Lỗi upload: ${err.message}`);
            progressText.textContent = 'Lỗi...';
            progressBar.style.backgroundColor = '#ef4444';
        } finally {
            // Clean up faster - shorter on mobile
            setTimeout(() => {
                uploadBtn.innerHTML = originalText;
                uploadBtn.disabled = false;
                uploadProgress.classList.add('hidden');
                progressBar.style.width = '0%';
                progressBar.style.backgroundColor = '#7b2ff7';
            }, mobileDelay(500));
        }
    }).catch((err) => {
        clearInterval(progressInterval);
        console.error('Compression error:', err);
        showErrorToast(`Lỗi xử lý ảnh: ${err.message}`);
        progressText.textContent = 'Lỗi...';
        progressBar.style.backgroundColor = '#ef4444';
        
        setTimeout(() => {
            uploadBtn.innerHTML = originalText;
            uploadBtn.disabled = false;
            uploadProgress.classList.add('hidden');
            progressBar.style.width = '0%';
            progressBar.style.backgroundColor = '#7b2ff7';
        }, mobileDelay(500));
    });
}

// ================== TOAST NOTIFICATIONS ==================
function showSuccessToast(message) {
    const toast = document.getElementById('successToast');
    toast.querySelector('span').textContent = message;
    toast.classList.remove('hidden');
    const duration = isMobile() ? 2000 : 3000;
    setTimeout(() => toast.classList.add('hidden'), duration);
}

function showErrorToast(message) {
    const toast = document.getElementById('successToast');
    toast.classList.add('bg-red-500'); // Override to red
    toast.querySelector('span').textContent = message;
    toast.classList.remove('hidden');
    const duration = isMobile() ? 2000 : 3000;
    setTimeout(() => {
        toast.classList.add('hidden');
        toast.classList.remove('bg-red-500'); // Reset to green
    }, duration);
}

// ================== MEMORY ACTIONS (Authenticated) ==================
document.addEventListener('click', async (e) => {
    if (e.target.closest('.delete-btn')) {
        const card = e.target.closest('.memory-card');
        const path = card.dataset.path;
        if (confirm('Bạn có chắc muốn xóa ảnh này?')) {
            try {
                const resp = await fetch('/.netlify/functions/delete-image', {
                    method: 'DELETE',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ path, password: classPassword })
                });
                if (resp.ok) {
                    showSuccessToast('Xóa ảnh thành công!');
                    loadMemories(); // Reload
                } else {
                    throw new Error('Delete failed');
                }
            } catch (err) {
                showErrorToast('Lỗi xóa ảnh!');
            }
        }
    }

    if (e.target.closest('.edit-btn')) {
        const card = e.target.closest('.memory-card');
        const path = card.dataset.path;
        const title = card.dataset.title || card.querySelector('.memory-title')?.textContent || '';
        const date = card.dataset.date || '';
        const modal = document.getElementById('editModal');
        document.getElementById('editPath').value = path;
        document.getElementById('editTitle').value = title;
        document.getElementById('editDate').value = date ? new Date(date).toISOString().slice(0,10) : '';
        if (modal) {
            modal.classList.remove('hidden');
            modal.setAttribute('tabindex', '-1');
            modal.setAttribute('aria-hidden', 'false');
            lockBodyScroll();
            trapFocus(modal);
        }
        if (typeof feather !== 'undefined') feather.replace();
    }
});

function showMemoryActions() {
    // Show delete/edit buttons if authenticated
    document.querySelectorAll('.memory-actions').forEach(actions => {
        actions.style.display = 'flex';
    });
}

// ================== MODALS ==================
document.addEventListener('click', (event) => {
    if (event.target.id === 'imageModal') {
        closeImageModal();
    }
    if (event.target.id === 'studentModal') {
        closeStudentModal();
    }
});

// Mobile menu toggle with improved UX
const mobileMenuBtn = document.querySelector('.mobile-menu-button');
const mobileMenu = document.getElementById('mobileMenu');
if (mobileMenuBtn && mobileMenu) {
    mobileMenuBtn.addEventListener('click', () => {
        const isHidden = mobileMenu.classList.contains('hidden');
        
        if (isHidden) {
            // Show menu
            mobileMenu.classList.remove('hidden');
            setTimeout(() => {
                mobileMenu.classList.remove('-translate-y-5', 'opacity-0');
            }, mobileDelay(10));
        } else {
            // Hide menu
            mobileMenu.classList.add('-translate-y-5', 'opacity-0');
            setTimeout(() => {
                mobileMenu.classList.add('hidden');
            }, mobileDelay(300));
        }
    });

    // Close menu when clicking outside
    document.addEventListener('click', (e) => {
        if (!mobileMenuBtn.contains(e.target) && !mobileMenu.contains(e.target)) {
            if (!mobileMenu.classList.contains('hidden')) {
                mobileMenu.classList.add('-translate-y-5', 'opacity-0');
                setTimeout(() => {
                    mobileMenu.classList.add('hidden');
                }, mobileDelay(300));
            }
        }
    });
}

// Scroll to Top/Bottom button
const scrollTopBtn = document.getElementById('scrollTopBtn');
const scrollProgressBar = document.getElementById('scrollProgressBar');

function updateScrollProgress() {
    const scrollTop = window.scrollY || document.documentElement.scrollTop;
    const docHeight = document.documentElement.scrollHeight - document.documentElement.clientHeight;
    const progress = docHeight > 0 ? (scrollTop / docHeight) * 100 : 0;
    if (scrollProgressBar) scrollProgressBar.style.width = progress + '%';
}

window.addEventListener('scroll', () => {
    if (window.scrollY > 200) {
        scrollTopBtn.classList.add('show');
        // Show up arrow for scroll to top
        scrollTopBtn.innerHTML = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="18 15 12 9 6 15"></polyline></svg>';
        scrollTopBtn.onclick = () => window.scrollTo({ top: 0, behavior: 'smooth' });
    } else {
        scrollTopBtn.classList.remove('show');
        // Show down arrow for scroll to bottom
        scrollTopBtn.innerHTML = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"></polyline></svg>';
        scrollTopBtn.onclick = () => window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' });
    }
    updateScrollProgress();
});

window.addEventListener('load', updateScrollProgress);

// Subtle parallax on hero image for better scroll feeling
const heroParallax = document.getElementById('heroParallax');
let lastKnownScrollY = 0;
let ticking = false;

function applyParallax() {
    const offset = lastKnownScrollY * 0.2; // slower than scroll
    if (heroParallax) heroParallax.style.transform = 'translateY(' + (-offset) + 'px)';
    ticking = false;
}

window.addEventListener('scroll', function() {
    lastKnownScrollY = window.scrollY || document.documentElement.scrollTop;
    if (!ticking) {
        window.requestAnimationFrame(applyParallax);
        ticking = true;
    }
});

// Counter animation when in viewport
function animateCounter(counter) {
    const target = +counter.getAttribute('data-target');
    const duration = 2000;
    const startTime = performance.now();
    function update(now) {
        const progress = Math.min((now - startTime) / duration, 1);
        counter.textContent = Math.floor(progress * target);
        if (progress < 1) requestAnimationFrame(update);
    }
    requestAnimationFrame(update);
}
// Optimize counters with IntersectionObserver
function initCountersObserver() {
    const counters = document.querySelectorAll('.counter');
    if (!('IntersectionObserver' in window) || counters.length === 0) {
        // Fallback
        counters.forEach(c => animateCounter(c));
        return;
    }
    const observer = new IntersectionObserver((entries, obs) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const el = entry.target;
                if (el.textContent === '0') animateCounter(el);
                obs.unobserve(el);
            }
        });
    }, { threshold: 0.4 });
    counters.forEach(c => observer.observe(c));
}
window.addEventListener('load', initCountersObserver);

// Student list generator
const studentContainer = document.getElementById('student-container');

// Danh sách học sinh (role là mảng) - Data thực tế, thêm trường order để giữ thứ tự
const students = [
    { name: 'Nguyễn Thị Thân Thương', role: ['monitor'], img: 'img/thuong.jpg', order: 0 },
    { name: 'Nguyễn Thu Hà', role: ['secretary'], img: 'img/hoangquocvuong.jpg', order: 1 },
    { name: 'Nguyễn Xuân Hưng', role: ['studying'], img: 'img/hoangquocvuong.jpg', order: 2 },
    { name: 'Nguyễn Đức Lĩnh', role: ['studying'], img: 'img/lĩnh.jpg', order: 3 },
    { name: 'Phạm Hà Vy', role: ['deputy-labor'], img: 'img/hoangquocvuong.jpg', order: 4 },
    { name: 'Nguyễn Duy Anh', role: ['group-leader-1'], img: 'img/hoangquocvuong.jpg', order: 5 },
    { name: 'Nguyễn Khánh Hưng', role: ['group-leader-2'], img: 'img/hoangquocvuong.jpg', order: 6 },
    { name: 'Hoàng Quốc Vương', role: ['group-leader-3'], img: 'img/vuong.jpg', order: 7 },
    { name: 'Nguyễn Thanh Chúc', role: ['member'], img: 'img/hoangquocvuong.jpg', order: 8 },
    { name: 'Nguyễn Mạnh Cường', role: ['member'], img: 'img/hoangquocvuong.jpg', order: 9 },
    { name: 'Nguyễn Thanh Thùy Dung', role: ['member'], img: 'img/hoangquocvuong.jpg', order: 10 },
    { name: 'Trần Đăng Dũng', role: ['member'], img: 'img/dung.jpg', order: 11 },
    { name: 'Trần Quang Định', role: ['member'], img: 'img/quangdinh.jpg', order: 12 },
    { name: 'Phạm Minh Đức', role: ['member'], img: 'img/hoangquocvuong.jpg', order: 13 },
    { name: 'Đỗ Trường Giang', role: ['member'], img: 'img/hoangquocvuong.jpg', order: 14 },
    { name: 'Nguyễn Trường Giang', role: ['member'], img: 'img/hoangquocvuong.jpg', order: 15 },
    { name: 'Nguyễn Khắc Hiếu', role: ['member'], img: 'img/hieu.jpg', order: 16 },
    { name: 'Vi Sỹ Hoan', role: ['member'], img: 'img/vihoan.jpg', order: 17 },
    { name: 'Nguyễn Văn Huy', role: ['member'], img: 'img/huy.jpg', order: 18 },
    { name: 'Nguyễn Phú Hưng', role: ['member'], img: 'img/phuhung.jpg', order: 19 },
    { name: 'Trần Vân Khánh', role: ['member'], img: 'img/vankhanh.jpg', order: 20 },
    { name: 'Lê Trung Kiên', role: ['member'], img: 'img/ADMIN.jpg', order: 21 },
    { name: 'Nguyễn Trung Kiên', role: ['member'], img: 'img/nguyenkien.jpg', order: 22 },
    { name: 'Nguyễn Bảo Lâm', role: ['member'], img: 'img/lam.jpg', order: 23 },
    { name: 'Nguyễn Thu Lê', role: ['member'], img: 'img/hoangquocvuong.jpg', order: 24 },
    { name: 'Lê Thị Ngọc Linh', role: ['member'], img: 'img/ngoclinh.jpg', order: 25 },
    { name: 'Nguyễn Hà Nhật Linh', role: ['member'], img: 'img/nhatlinh.jpg', order: 26 },
    { name: 'Nguyễn Hoàng Linh', role: ['member'], img: 'img/hoangquocvuong.jpg', order: 27 },
    { name: 'Phạm Bảo Nhật Linh', role: ['member'], img: 'img/hoangquocvuong.jpg', order: 28 },
    { name: 'Bùi Khánh Ly', role: ['member'], img: 'img/hoangquocvuong.jpg', order: 29 },
    { name: 'Kiều Ngọc Mai', role: ['member'], img: 'img/hoangquocvuong.jpg', order: 30 },
    { name: 'Nguyễn Xuân Mai', role: ['member'], img: 'img/hoangquocvuong.jpg', order: 31 },
    { name: 'Nguyễn Hoàng Minh', role: ['member'], img: 'img/minh.jpg', order: 32 },
    { name: 'Ngô Nguyên Hải Nam', role: ['member'], img: 'img/hoangquocvuong.jpg', order: 33 },
    { name: 'Nguyễn Thành Nam', role: ['member'], img: 'img/hoangquocvuong.jpg', order: 34 },
    { name: 'Nguyễn Hoàng Bích Ngọc', role: ['member'], img: 'img/hoangquocvuong.jpg', order: 35 },
    { name: 'Vũ Bảo Ngọc', role: ['member'], img: 'img/hoangquocvuong.jpg', order: 36 },
    { name: 'Phạm Công Sơn', role: ['member'], img: 'img/hoangquocvuong.jpg', order: 37 },
    { name: 'Nguyễn Thanh Thảo', role: ['member'], img: 'img/thanhthao.jpg', order: 38 },
    { name: 'Vũ Kim Huệ', role: ['member'], img: 'img/hue.jpg', order: 39 },
    { name: 'Hoàng Mạnh Tiến', role: ['member'], img: 'img/tien.jpg', order: 40 },
    { name: 'Nguyễn Thu Trang', role: ['member'], img: 'img/trang.jpg', order: 41 },
    { name: 'Nguyễn Thanh Tuyền', role: ['member'], img: 'img/tuyen.jpg', order: 42 },
    { name: 'Đỗ Thy', role: ['member'], img: 'img/thy.jpg', order: 43 },
    { name: 'Lưu Phương Vy', role: ['member'], img: 'img/phuongvy.jpg', order: 44 }
];

// Students state
let sortedStudents = [];
let currentFilter = 'all';
let displayedCount = 0; // Track how many students are currently displayed
let studentCurrentPage = 1; // used for mobile pagination

// Detect if mobile (less than 768px width)
function isMobile() {
    return window.innerWidth < 768;
}

// Return a shorter delay on mobile for snappier UX
function mobileDelay(ms) {
    try {
        return isMobile() ? Math.max(30, Math.floor(ms * 0.45)) : ms;
    } catch (e) {
        return ms;
    }
}

// Get items per page based on device
function getItemsPerPage() {
    return isMobile() ? 4 : 10; // 4 on mobile, 10 on desktop (2 rows of 5)
}

// Helper: Lấy text role cho badge (thay 'monitor' thành 'Lớp trưởng')
function getRoleText(role) {
    const texts = {
        'monitor': 'Lớp trưởng',
        'secretary': 'Thư ký lớp',
        'studying': 'Phó học tập',
        'deputy-labor': 'Phó lao động',
        'group-leader-1': 'Tổ trưởng 1',
        'group-leader-2': 'Tổ trưởng 2',
        'group-leader-3': 'Tổ trưởng 3',
        'member': 'Thành viên'
    };
    return texts[role] || 'Thành viên';
}

// Function để render students theo thứ tự order (từ nhỏ đến lớn)
function renderStudents(studentsToRender = students) {
    // Sắp xếp theo order để đảm bảo thứ tự cố định
    const sorted = [...studentsToRender].sort((a, b) => a.order - b.order);
    sortedStudents = sorted;
    displayedCount = 0; // Reset count
    studentCurrentPage = 1;

    const container = document.getElementById('student-container');
    if (!container) {
        console.error('Không tìm thấy #student-container!');
        return;
    }
    container.innerHTML = '';

    const countEl = document.getElementById('studentCount');
    if (countEl) countEl.textContent = sortedStudents.length;

    // Show all students on both mobile and desktop (remove pagination)
    showAllStudents();
    // Hide both mobile and desktop pagination controls if present
    const mobilePag = document.getElementById('studentMobilePagination');
    if (mobilePag) mobilePag.classList.add('hidden');
    const loadMore = document.getElementById('loadMoreContainer');
    if (loadMore) loadMore.classList.add('hidden');
}

// Function to render a specific page (mobile pagination)
function renderStudentsPage(page) {
    const container = document.getElementById('student-container');
    if (!container) return;

    const itemsPerPage = getItemsPerPage();
    const totalPages = Math.max(1, Math.ceil(sortedStudents.length / itemsPerPage));
    studentCurrentPage = Math.min(Math.max(1, page), totalPages);

    const startIndex = (studentCurrentPage - 1) * itemsPerPage;
    const endIndex = Math.min(startIndex + itemsPerPage, sortedStudents.length);

    container.innerHTML = '';
    const stagger = isMobile() ? 20 : 50;
    for (let i = startIndex; i < endIndex; i++) {
        const student = sortedStudents[i];
        setTimeout(() => {
            renderStudentCard(student, container, i);
        }, (i - startIndex) * stagger);
    }

    displayedCount = endIndex;
    setTimeout(() => {
        updateMobilePagination(totalPages);
        if (typeof feather !== 'undefined') feather.replace();
    }, mobileDelay(120));
}

// Function to load more students (desktop load-more)
function loadMoreStudents() {
    const container = document.getElementById('student-container');
    if (!container) return;

    const itemsPerPage = getItemsPerPage();
    const startIndex = displayedCount;
    const endIndex = Math.min(startIndex + itemsPerPage, sortedStudents.length);

    // Render new batch
    const stagger = isMobile() ? 20 : 50;
    for (let i = startIndex; i < endIndex; i++) {
        const student = sortedStudents[i];
        setTimeout(() => {
            renderStudentCard(student, container, i);
        }, (i - startIndex) * stagger);
    }

    displayedCount = endIndex;

    // Show/hide "Xem thêm" button
    setTimeout(() => {
        updateLoadMoreButton();
        if (typeof feather !== 'undefined') feather.replace();
    }, mobileDelay(100));
}

// Function to update "Xem thêm" button visibility (desktop)
function updateLoadMoreButton() {
    const loadMoreBtn = document.getElementById('loadMoreContainer');
    if (!loadMoreBtn) return;

    if (displayedCount < sortedStudents.length) {
        loadMoreBtn.classList.remove('hidden');
    } else {
        loadMoreBtn.classList.add('hidden');
    }
}

// Mobile pagination controls
function updateMobilePagination(totalPages) {
    const pag = document.getElementById('studentMobilePagination');
    if (!pag) return;
    pag.innerHTML = '';
    // Build pagination: prev, page numbers, next
    const wrapper = document.createElement('div');
    wrapper.className = 'inline-flex items-center gap-2 flex-wrap justify-center';

    const prev = document.createElement('button');
    prev.className = 'px-3 py-2 bg-white/10 rounded disabled:opacity-50';
    prev.setAttribute('aria-label', 'Trang trước');
    prev.textContent = '‹';
    prev.disabled = studentCurrentPage <= 1;
    prev.onclick = () => { if (studentCurrentPage > 1) renderStudentsPage(studentCurrentPage - 1); };
    wrapper.appendChild(prev);

    // render page numbers (compact if many)
    const maxButtons = 7;
    let start = Math.max(1, studentCurrentPage - Math.floor(maxButtons/2));
    let end = start + maxButtons - 1;
    if (end > totalPages) { end = totalPages; start = Math.max(1, end - maxButtons + 1); }

    for (let p = start; p <= end; p++) {
        const btn = document.createElement('button');
        btn.className = `px-3 py-2 rounded ${p===studentCurrentPage? 'bg-purple-600 text-white' : 'bg-white/10'}`;
        btn.textContent = p;
        btn.setAttribute('aria-label', `Trang ${p}`);
        if (p === studentCurrentPage) btn.disabled = true;
        btn.onclick = (() => { const page = p; return () => renderStudentsPage(page); })();
        wrapper.appendChild(btn);
    }

    const next = document.createElement('button');
    next.className = 'px-3 py-2 bg-white/10 rounded disabled:opacity-50';
    next.setAttribute('aria-label', 'Trang sau');
    next.textContent = '›';
    next.disabled = studentCurrentPage >= totalPages;
    next.onclick = () => { if (studentCurrentPage < totalPages) renderStudentsPage(studentCurrentPage + 1); };
    wrapper.appendChild(next);

    pag.appendChild(wrapper);
}

// Show all students at once (desktop)
function showAllStudents() {
    const container = document.getElementById('student-container');
    if (!container) return;
    container.innerHTML = '';
    for (let i = 0; i < sortedStudents.length; i++) {
        const student = sortedStudents[i];
        renderStudentCard(student, container, i);
    }
    displayedCount = sortedStudents.length;
    // hide desktop controls after showing all
    const loadMore = document.getElementById('loadMoreContainer');
    if (loadMore) loadMore.classList.add('hidden');
}

// Re-render when viewport crosses mobile/desktop threshold
let _lastIsMobile = isMobile();
window.addEventListener('resize', () => {
    const nowMobile = isMobile();
    if (nowMobile !== _lastIsMobile) {
        _lastIsMobile = nowMobile;
        // re-render list for the new layout
        renderStudents(sortedStudents);
    }
});

function renderStudentCard(student, container, index = 0) {
    const defaultImg = 'img/default.jpg';

    // Badge (loop mảng)
    let roleBadges = '';
    student.role.forEach(role => {
        let badgeClass = '';
        let badgeText = getRoleText(role);
        if (role === 'monitor') {
            badgeClass = 'monitor-badge'; 
        } else if (role === 'secretary') {
            badgeClass = 'secretary-badge'; 
        } else if (role === 'group-leader-1' || role === 'group-leader-2' || role === 'group-leader-3') {
            badgeClass = 'group-leader-badge'; 
        } else if (role === 'deputy-labor' || role === 'studying') {
            badgeClass = 'assistant-badge'; 
        } else {
            badgeClass = 'member-badge'; 
        }
        roleBadges += `<span class="role-badge ${badgeClass}">${badgeText}</span>`;
    });

    // Card HTML (tất cả đều dùng student-card)
    const card = document.createElement('div');
    card.className = `student-card bg-white rounded-xl shadow-md overflow-hidden transition duration-300 hover:shadow-lg fade-in-up flex flex-col`;
    card.setAttribute('data-role', student.role.join(' '));
    card.dataset.order = student.order;
    card.style.animationDelay = `${index * 0.07}s`;
    card.style.cursor = 'pointer';
    // Keep original behavior without extra AOS attributes here
    card.onclick = (e) => {
        if (e.target.classList.contains('role-badge')) return;
        openStudentModal(student.name, student.img, roleBadges);
    };
    card.innerHTML = `
        <div class="h-48 w-full flex items-center justify-center overflow-hidden bg-gradient-to-br from-gray-50 to-gray-100">
            <img src="${student.img}" alt="${escapeHtml(student.name)}" 
                class="h-full w-full object-cover"
                onerror="this.src='${defaultImg}';"
                loading="lazy">
        </div>
        <div class="p-5 flex-grow">
            <h3 class="font-bold text-lg">${escapeHtml(student.name)}</h3>
            <div class="mt-3 flex flex-wrap">
                ${roleBadges}
            </div>
        </div>
    `;
    container.appendChild(card);
}

// Function mở modal (nếu chưa có, thêm vào)
function openStudentModal(name, img, badgesHtml) {
    const modalImg = document.getElementById('studentModalImg');
    const modalName = document.getElementById('studentModalName');
    const modalRole = document.getElementById('studentModalRole');
    const modal = document.getElementById('studentModal');
    if (modalImg) modalImg.src = img;
    if (modalName) modalName.textContent = name;
    if (modalRole) modalRole.innerHTML = badgesHtml; // Hiển thị multiple badges
    if (modal) {
        modal.classList.remove('hidden');
        modal.classList.add('show');
        modal.setAttribute('tabindex', '-1');
        modal.setAttribute('aria-hidden', 'false');
        lockBodyScroll();
        trapFocus(modal);
    }
    if (typeof feather !== 'undefined') feather.replace();
}

// Open image modal
window.openImageModal = function(src) {
    const modal = document.getElementById('imageModal');
    const modalImage = document.getElementById('modalImage');
    if (modal && modalImage) {
        modalImage.src = src;
        modal.classList.remove('hidden');
        modal.classList.add('show');
        modal.setAttribute('tabindex', '-1');
        modal.setAttribute('aria-hidden', 'false');
        lockBodyScroll();
        trapFocus(modal);
    }
};

// Close image modal
window.closeImageModal = function() {
    const modal = document.getElementById('imageModal');
    if (modal) {
        modal.classList.add('hidden');
        modal.setAttribute('aria-hidden', 'true');
    }
    releaseFocusTrap();
    unlockBodyScroll();
};

// Open file preview modal
window.openFilePreview = function(url, fileName) {
    const modal = document.getElementById('filePreviewModal');
    const content = document.getElementById('previewContent');
    const title = document.getElementById('previewTitle');
    
    if (!modal || !content || !title) return;
    
    title.textContent = fileName;
    
    // Determine file type from extension
    const ext = fileName.toLowerCase().split('.').pop();
    
    // Create preview based on file type
    let previewHTML = '';
    
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].includes(ext)) {
        previewHTML = `<img src="${url}" alt="${escapeHtml(fileName)}" class="max-w-full h-auto mx-auto rounded" />`;
    } 
    else if (ext === 'pdf') {
        previewHTML = `
            <div class="space-y-4">
                <p class="text-gray-600">Xem PDF trực tiếp hoặc tải về để xem đầy đủ:</p>
                <iframe src="${url}#toolbar=0" width="100%" height="600" style="border: 1px solid #ddd; border-radius: 6px;"></iframe>
                <div class="text-center">
                    <a href="${url}" target="_blank" rel="noopener noreferrer" class="inline-block bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700">
                        <i class="fas fa-download mr-2"></i>Tải xuống PDF
                    </a>
                </div>
            </div>
        `;
    }
    else if (['xls', 'xlsx'].includes(ext)) {
        previewHTML = `
            <div class="space-y-4">
                <p class="text-gray-600">File Excel không thể xem trực tiếp trên web. Vui lòng tải về để xem:</p>
                <div class="bg-gray-100 p-8 rounded-lg text-center">
                    <i class="fas fa-file-excel text-6xl text-green-600 mb-4"></i>
                    <p class="font-semibold text-gray-700 mb-4">${escapeHtml(fileName)}</p>
                    <a href="${url}" target="_blank" rel="noopener noreferrer" class="inline-block bg-green-600 text-white px-6 py-2 rounded-lg hover:bg-green-700">
                        <i class="fas fa-download mr-2"></i>Tải xuống
                    </a>
                </div>
            </div>
        `;
    }
    else if (['doc', 'docx'].includes(ext)) {
        previewHTML = `
            <div class="space-y-4">
                <p class="text-gray-600">File Word không thể xem trực tiếp trên web. Vui lòng tải về để xem:</p>
                <div class="bg-gray-100 p-8 rounded-lg text-center">
                    <i class="fas fa-file-word text-6xl text-blue-600 mb-4"></i>
                    <p class="font-semibold text-gray-700 mb-4">${escapeHtml(fileName)}</p>
                    <a href="${url}" target="_blank" rel="noopener noreferrer" class="inline-block bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700">
                        <i class="fas fa-download mr-2"></i>Tải xuống
                    </a>
                </div>
            </div>
        `;
    }
    else {
        previewHTML = `
            <div class="space-y-4">
                <p class="text-gray-600">Không thể xem trước file này. Vui lòng tải về để xem:</p>
                <div class="bg-gray-100 p-8 rounded-lg text-center">
                    <i class="fas fa-file text-6xl text-gray-400 mb-4"></i>
                    <p class="font-semibold text-gray-700 mb-4">${escapeHtml(fileName)}</p>
                    <a href="${url}" target="_blank" rel="noopener noreferrer" class="inline-block bg-gray-600 text-white px-6 py-2 rounded-lg hover:bg-gray-700">
                        <i class="fas fa-download mr-2"></i>Tải xuống
                    </a>
                </div>
            </div>
        `;
    }
    
    content.innerHTML = previewHTML;
    modal.classList.remove('hidden');
    modal.setAttribute('aria-hidden', 'false');
    lockBodyScroll();
    trapFocus(modal);
};

// Close file preview modal
window.closeFilePreviewModal = function() {
    const modal = document.getElementById('filePreviewModal');
    if (modal) {
        modal.classList.add('hidden');
        modal.setAttribute('aria-hidden', 'true');
    }
    releaseFocusTrap();
    unlockBodyScroll();
};

// Close student modal
window.closeStudentModal = function() {
    const modal = document.getElementById('studentModal');
    if (modal) {
        modal.classList.add('hidden');
        modal.setAttribute('aria-hidden', 'true');
    }
    releaseFocusTrap();
    unlockBodyScroll();
};

// Thêm vào DOMContentLoaded để init students với thứ tự order
document.addEventListener('DOMContentLoaded', function() {
    // Mobile Menu Toggle
    const mobileMenuBtn = document.getElementById('mobileMenuBtn');
    const mobileMenu = document.getElementById('mobileMenu');
    if (mobileMenuBtn && mobileMenu) {
        mobileMenuBtn.addEventListener('click', () => {
            mobileMenu.classList.toggle('hidden');
            mobileMenuBtn.classList.toggle('rotate-90', !mobileMenu.classList.contains('hidden'));
            mobileMenuBtn.style.transition = 'transform 0.3s ease';
        });

        // Close menu when clicking on mobile menu links
        mobileMenu.querySelectorAll('a').forEach(link => {
            link.addEventListener('click', () => {
                mobileMenu.classList.add('hidden');
                if (mobileMenuBtn) mobileMenuBtn.classList.remove('rotate-90');
            });
        });
    }

    // Render theo thứ tự order
    renderStudents(students);

    // Filter students
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.filter-btn').forEach(b =>
                b.classList.remove('active', 'bg-white', 'text-purple-600')
            );
            btn.classList.add('active', 'bg-white', 'text-purple-600');

            const filter = btn.dataset.filter;
            const filterRoles = filter.split(' ');

            if (filter === 'all') {
                // Render theo thứ tự order
                renderStudents(students);
            } else {
                // Filter theo role, rồi sort theo order để giữ thứ tự gốc
                const filteredStudents = students.filter(student =>
                    student.role.some(role => filterRoles.includes(role))
                );
                // Render với thứ tự order
                renderStudents(filteredStudents);
            }
        });
    });

    // Dark mode removed: toggle button and persistence deleted

    // Smooth scroll with offset
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            const targetId = this.getAttribute('href').substring(1);
            const targetEl = document.getElementById(targetId);
            if (targetEl) {
                e.preventDefault();
                const yOffset = -80; // cao khoảng navbar
                const y = targetEl.getBoundingClientRect().top + window.scrollY + yOffset;

                window.scrollTo({ top: y, behavior: 'smooth' });
            }
        });
    });

    // Placeholder for other functions
    function showMemoryActions() {
        // Show delete/edit buttons if authenticated
        document.querySelectorAll('.memory-actions').forEach(actions => {
            actions.style.display = 'flex';
        });
    }

    // (updateUploadButtonUI is defined globally above) - removed duplicate to avoid overwriting

    // Open image modal
    window.openImageModal = function(src) {
        const modal = document.getElementById('imageModal');
        const modalImage = document.getElementById('modalImage');
        if (modal && modalImage) {
            modalImage.src = src;
            modal.classList.remove('hidden');
            modal.setAttribute('tabindex', '-1');
            modal.setAttribute('aria-hidden', 'false');
            lockBodyScroll();
            trapFocus(modal);
        }
    };

    // Close image modal
    // Note: closeImageModal and closeStudentModal are defined above (lines 1341-1352)
    // Do not redefine here to ensure releaseFocusTrap() and unlockBodyScroll() are always called

    // Load TKB files
    loadTKBFiles();

    // Load Scores
    loadScores();

    // Update TKB upload button visibility
    updateTKBUploadButtonUI();
    
    // Update Score upload button visibility
    updateScoreUploadButtonUI();

    // Ensure AOS is initialized with mobile-aware durations after page render
    if (window.AOS) {
        try {
            AOS.init({
                duration: isMobile() ? 700 : 1000,
                once: false,
                offset: 120,
                easing: 'ease-in-out-sine',
                mirror: true
            });
        } catch (e) {
            // Non-fatal
            console.warn('AOS init override failed', e);
        }
    }
});

// ================== SCORES FUNCTIONS ==================
let scoresData = [];
let scoreCurrentYearFilter = '2025-2026';
let scoreCurrentSemesterFilter = 'all';
let scoreCurrentPage = 1;
const SCORE_ITEMS_PER_PAGE = 6;
const SEMESTER_LABELS = {
    "survey":"Điểm khảo sát",
    'mid1': 'Giữa HK1',
    'final1': 'Cuối HK1',
    'mid2': 'Giữa HK2',
    'final2': 'Cuối HK2',
    'all': 'Tất Cả'
};

async function loadScores() {
    try {
        const response = await fetch('/.netlify/functions/get-scores');
        if (response.ok) {
            scoresData = await response.json();
            // Sort by year descending, then semester descending, then by upload time descending
            scoresData.sort((a, b) => {
                const semesterOrder = { 'survey': 5, 'final2': 4, 'mid2': 3, 'final1': 2, 'mid1': 1 };
                if (a.year !== b.year) {
                    return b.year.localeCompare(a.year);
                }
                const semA = semesterOrder[a.semester] || 0;
                const semB = semesterOrder[b.semester] || 0;
                if (semA !== semB) return semB - semA;
                return new Date(b.uploadedAt) - new Date(a.uploadedAt);
            });
            renderScores();
        }
    } catch (err) {
        console.error('Error loading scores:', err);
    }
}

function filterScoresByYear(year) {
    scoreCurrentYearFilter = year;
    scoreCurrentPage = 1;
    
    // Update button styles
    document.querySelectorAll('[data-year]').forEach(btn => {
        btn.classList.remove('active', 'bg-opacity-20');
        btn.classList.add('bg-white', 'bg-opacity-10');
    });
    
    const activeBtn = document.querySelector(`[data-year="${year}"]`);
    if (activeBtn) {
        activeBtn.classList.add('active', 'bg-opacity-20');
        activeBtn.classList.remove('bg-opacity-10');
    }
    
    renderScores();
}

function filterScoresBySemester(semester) {
    scoreCurrentSemesterFilter = semester;
    scoreCurrentPage = 1;
    
    // Update button styles
    document.querySelectorAll('[data-semester]').forEach(btn => {
        btn.classList.remove('active', 'bg-opacity-20');
        btn.classList.add('bg-white', 'bg-opacity-10');
    });
    
    const activeBtn = document.querySelector(`[data-semester="${semester}"]`);
    if (activeBtn) {
        activeBtn.classList.add('active', 'bg-opacity-20');
        activeBtn.classList.remove('bg-opacity-10');
    }
    
    renderScores();
}

function renderScores() {
    const container = document.getElementById('scoreCardsList');
    if (!container) return;
    
    // Filter scores
    let filteredScores = scoresData.filter(s => s.year === scoreCurrentYearFilter);
    if (scoreCurrentSemesterFilter !== 'all') {
        filteredScores = filteredScores.filter(s => s.semester === scoreCurrentSemesterFilter);
    }
    
    // Empty state
    if (filteredScores.length === 0) {
        container.innerHTML = `
            <div class="text-center py-12 col-span-full">
                <i class="fas fa-chart-bar text-4xl opacity-50 mb-4"></i>
                <p class="text-gray-200">Chưa có bảng điểm nào. Hãy quay lại sau!</p>
            </div>
        `;
        document.getElementById('scorePagination').innerHTML = '';
        return;
    }
    
    // Pagination
    const totalItems = filteredScores.length;
    const totalPages = Math.max(1, Math.ceil(totalItems / SCORE_ITEMS_PER_PAGE));
    if (scoreCurrentPage > totalPages) scoreCurrentPage = 1;
    
    const start = (scoreCurrentPage - 1) * SCORE_ITEMS_PER_PAGE;
    const end = start + SCORE_ITEMS_PER_PAGE;
    const paginatedScores = filteredScores.slice(start, end);
    
    // Render cards
    container.innerHTML = paginatedScores.map(score => {
        const uploadDate = new Date(score.uploadedAt).toLocaleDateString('vi-VN');
        return `
            <div class="bg-white bg-opacity-10 rounded-lg p-6 hover:bg-opacity-20 transition transform hover:scale-105" data-aos="fade-up">
                <div class="flex justify-between items-start mb-4">
                    <div>
                        <p class="text-sm text-gray-300">Năm học: ${score.year}</p>
                        <p class="text-sm font-semibold text-yellow-300">${SEMESTER_LABELS[score.semester] || score.semester}</p>
                    </div>
                    ${isAuthenticated ? `<button onclick="deleteScore('${score.id}')" class="text-red-300 hover:text-red-100 transition" title="Xóa"><i class="fas fa-trash text-xl"></i></button>` : ''}
                </div>
                <p class="text-lg font-bold mb-4">${escapeHtml(score.fileName)}</p>
                <p class="text-xs text-gray-400 mb-4">Tải lên: ${uploadDate}</p>
                <div class="flex gap-3">
                    <button onclick="openFilePreview('${score.url}', '${escapeHtml(score.fileName).replace(/'/g, "\\'")}'" class="inline-flex items-center bg-blue-500 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-600 transition">
                        <i class="fas fa-eye mr-2"></i>Xem
                    </button>
                    <a href="${score.url}" target="_blank" rel="noopener noreferrer" class="inline-flex items-center bg-yellow-400 text-gray-900 px-6 py-2 rounded-lg font-semibold hover:bg-yellow-300 transition">
                        <i class="fas fa-download mr-2"></i>Tải xuống
                    </a>
                </div>
            </div>
        `;
    }).join('');
    
    renderScorePagination(totalPages);
}

function renderScorePagination(totalPages) {
    const container = document.getElementById('scorePagination');
    if (!container) return;
    
    if (totalPages <= 1) {
        container.innerHTML = '';
        return;
    }
    
    let html = `
        <button class="score-pagination-btn ${scoreCurrentPage === 1 ? 'disabled opacity-50 cursor-not-allowed' : ''}" ${scoreCurrentPage === 1 ? 'disabled' : ''} onclick="if(${scoreCurrentPage} > 1) { scoreCurrentPage--; renderScores(); }">
            <i class="fas fa-chevron-left"></i> Trước
        </button>
    `;
    
    for (let i = 1; i <= totalPages; i++) {
        html += `<button class="score-pagination-btn ${i === scoreCurrentPage ? 'active bg-yellow-400 text-gray-900' : ''}" onclick="scoreCurrentPage=${i}; renderScores()">${i}</button>`;
    }
    
    html += `
        <button class="score-pagination-btn ${scoreCurrentPage === totalPages ? 'disabled opacity-50 cursor-not-allowed' : ''}" ${scoreCurrentPage === totalPages ? 'disabled' : ''} onclick="if(${scoreCurrentPage} < ${totalPages}) { scoreCurrentPage++; renderScores(); }">
            Sau <i class="fas fa-chevron-right"></i>
        </button>
        <span class="text-gray-400 ml-4">Trang ${scoreCurrentPage} / ${totalPages}</span>
    `;
    
    container.innerHTML = html;
}

async function openScoreUploadModal() {
    if (!isAuthenticated) {
        pendingUploadAction = 'score';
        openPasswordModal();
        return;
    }
    const modal = document.getElementById('scoreUploadModal');
    if (modal) {
        modal.classList.remove('hidden');
        modal.setAttribute('tabindex', '-1');
        modal.setAttribute('aria-hidden', 'false');
        lockBodyScroll();
        trapFocus(modal);
    }
}

function closeScoreUploadModal() {
    const modal = document.getElementById('scoreUploadModal');
    if (modal) {
        modal.classList.add('hidden');
        modal.setAttribute('aria-hidden', 'true');
    }
    releaseFocusTrap();
    unlockBodyScroll();
}

async function uploadScoreFile() {
    if (!isAuthenticated) {
        showErrorToast('Bạn cần xác thực trước khi upload!');
        return;
    }
    
    const year = document.getElementById('scoreYear').value;
    const semester = document.getElementById('scoreSemester').value;
    const file = document.getElementById('scoreFile').files[0];
    
    if (!year || !semester || !file) {
        showErrorToast('Vui lòng chọn đủ thông tin!');
        return;
    }
    
    const uploadBtn = document.querySelector('#scoreUploadForm button[type="button"]:last-child');
    const originalBtnText = uploadBtn.innerHTML;
    uploadBtn.disabled = true;
    uploadBtn.textContent = 'Đang upload...';

    try {
        // Use arrayBuffer for faster processing
        const arrayBuffer = await file.arrayBuffer();
        const base64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)));
        const fileName = file.name;
        const fileType = file.type || 'application/octet-stream';
        
        const response = await fetch('/.netlify/functions/upload-scores', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ year, semester, file: 'data:' + fileType + ';base64,' + base64, fileName, fileType })
        });
        
        if (response.ok) {
            showSuccessToast('Upload bảng điểm thành công!');
            document.getElementById('scoreUploadForm').reset();
            document.getElementById('scoreFileName').classList.add('hidden');
            closeScoreUploadModal();
            loadScores();
        } else {
            const error = await response.json();
            showErrorToast('Lỗi upload: ' + (error.message || 'Unknown error'));
        }
    } catch (err) {
        console.error('Upload score error:', err);
        showErrorToast('Lỗi upload: ' + err.message);
    } finally {
        uploadBtn.innerHTML = originalBtnText;
        uploadBtn.disabled = false;
    }
}

async function deleteScore(id) {
    if (!isAuthenticated) {
        alert('Bạn cần xác thực!');
        return;
    }
    
    if (!confirm('Bạn chắc chắn muốn xóa bảng điểm này?')) return;
    
    try {
        const response = await fetch('/.netlify/functions/delete-scores', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id })
        });
        
        if (response.ok) {
            alert('Xóa thành công!');
            loadScores();
        } else {
            alert('Lỗi xóa bảng điểm!');
        }
    } catch (err) {
        console.error('Delete error:', err);
        alert('Lỗi xóa: ' + err.message);
    }
}

function updateScoreUploadButtonUI() {
    const btn = document.getElementById('uploadScoreBtn');
    if (btn) {
        btn.style.display = isAuthenticated ? 'inline-flex' : 'none';
    }
}
// ================== TKB FUNCTIONS ==================
let tkbFiles = [];
let tkbCurrentFilter = 'all';
let tkbCurrentPage = 1;
const TKB_ITEMS_PER_PAGE = 6;

async function loadTKBFiles() {
    try {
        showLoadingState(true);
        const response = await fetch('/.netlify/functions/get-tkb-files');
        if (response.ok) {
            tkbFiles = await response.json();
            // Sort by class (10, 11, 12) then by number descending (12, 11, 10...)
            tkbFiles.sort((a, b) => {
                if (a.class !== b.class) {
                    return parseInt(a.class) - parseInt(b.class);
                }
                return parseInt(b.tkbNumber) - parseInt(a.tkbNumber);
            });
            renderTKBFiles();
        }
    } catch (err) {
        console.error('Error loading TKB files:', err);
    } finally {
        showLoadingState(false);
    }
}

function filterTKBByClass(classNum) {
    tkbCurrentFilter = classNum;
    tkbCurrentPage = 1; // reset to first page on filter change
    
    // Update button styles
    document.querySelectorAll('.filter-tkb-btn').forEach(btn => {
        btn.classList.remove('active', 'bg-white', 'bg-opacity-20');
        btn.classList.add('bg-white', 'bg-opacity-10');
    });
    
    const activeBtn = document.querySelector(`[data-class="${classNum}"]`);
    if (activeBtn) {
        activeBtn.classList.add('active', 'bg-opacity-20');
        activeBtn.classList.remove('bg-opacity-10');
    }
    
    renderTKBFiles();
}

function renderTKBFiles() {
    const container = document.getElementById('tkbFilesList');
    const paginationContainer = document.getElementById('tkbPagination');
    if (!container) return;

    // Filter files
    let filteredFiles = tkbFiles;
    if (tkbCurrentFilter !== 'all') {
        filteredFiles = tkbFiles.filter(f => f.class === tkbCurrentFilter);
    }

    if (filteredFiles.length === 0) {
        container.innerHTML = `
            <div class="text-center py-12 col-span-full">
                <i class="fas fa-calendar-alt text-4xl opacity-50 mb-4"></i>
                <p class="text-gray-200">Chưa có file TKB nào cho khối này. Hãy quay lại sau!</p>
            </div>
        `;
        if (paginationContainer) paginationContainer.innerHTML = '';
        return;
    }

    // Pagination
    const totalItems = filteredFiles.length;
    const totalPages = Math.max(1, Math.ceil(totalItems / TKB_ITEMS_PER_PAGE));
    if (tkbCurrentPage < 1) tkbCurrentPage = 1;
    if (tkbCurrentPage > totalPages) tkbCurrentPage = totalPages;
    const start = (tkbCurrentPage - 1) * TKB_ITEMS_PER_PAGE;
    const end = start + TKB_ITEMS_PER_PAGE;
    const paginated = filteredFiles.slice(start, end);

    container.innerHTML = paginated.map((file, idx) => `
        <div class="bg-white bg-opacity-10 p-6 rounded-xl backdrop-blur-sm hover:scale-105 transition border border-white/20 tkb-card" data-aos="zoom-in" data-aos-delay="${idx * (isMobile() ? 60 : 150)}">
            <div class="flex items-start gap-4">
                <div class="flex-shrink-0">
                    ${file.type === 'docx' ? 
                        `<i class="fas fa-file-word text-blue-300 text-3xl"></i>` :
                        file.type === 'pdf' ? 
                        `<i class="fas fa-file-pdf text-red-400 text-3xl"></i>` : 
                        `<i class="fas fa-image text-cyan-400 text-3xl"></i>`
                    }
                </div>
                <div class="flex-grow">
                    <div class="flex items-center gap-2 mb-2">
                        <h4 class="font-semibold text-lg text-white">TKB Số ${file.tkbNumber}</h4>
                        <span class="px-2 py-1 bg-white bg-opacity-20 rounded text-xs font-semibold">Lớp ${file.class}</span>
                    </div>
                    <p class="text-sm text-gray-300 mb-4">${new Date(file.uploadedAt).toLocaleDateString('vi-VN')}</p>
                    <div class="flex gap-2 flex-wrap">
                        <button onclick="openFilePreview('${file.url}', 'TKB Số ${file.tkbNumber} - Lớp ${file.class}')" class="px-4 py-2 bg-cyan-500 text-white rounded-lg hover:bg-cyan-600 transition text-sm font-semibold">
                            <i class="fas fa-eye mr-2"></i>Xem
                        </button>
                        <a href="${file.url}" target="_blank" download class="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition text-sm font-semibold">
                            <i class="fas fa-download mr-2"></i>Tải
                        </a>
                        ${isAuthenticated ? `
                            <button onclick="deleteTKBFile('${file.id}')" class="px-4 py-2 bg-red-500 text-white rounded-lg hover:bg-red-600 transition text-sm font-semibold">
                                <i class="fas fa-trash mr-2"></i>Xóa
                            </button>
                        ` : ''}
                    </div>
                </div>
            </div>
        </div>
    `).join('');

    // Render pagination controls
    if (paginationContainer) renderTKBPagination(totalPages);

    if (typeof feather !== 'undefined') feather.replace();
}

function renderTKBPagination(totalPages) {
    const paginationContainer = document.getElementById('tkbPagination');
    if (!paginationContainer) return;
    paginationContainer.innerHTML = '';

    // Page info
    const info = document.createElement('span');
    info.className = 'text-white text-sm mr-4 tkb-page-info';
    info.textContent = `Trang ${tkbCurrentPage} / ${totalPages}`;
    paginationContainer.appendChild(info);

    // Prev button
    const prevBtn = document.createElement('button');
    prevBtn.className = `tkb-pagination-btn ${tkbCurrentPage === 1 ? 'disabled' : ''}`;
    prevBtn.textContent = '«';
    prevBtn.disabled = tkbCurrentPage === 1;
    prevBtn.onclick = () => { if (tkbCurrentPage > 1) { tkbCurrentPage--; renderTKBFiles(); } };
    paginationContainer.appendChild(prevBtn);

    // Page numbers (limit to reasonable range)
    const maxPageButtons = 7;
    let startPage = Math.max(1, tkbCurrentPage - Math.floor(maxPageButtons / 2));
    let endPage = startPage + maxPageButtons - 1;
    if (endPage > totalPages) { endPage = totalPages; startPage = Math.max(1, endPage - maxPageButtons + 1); }

    for (let p = startPage; p <= endPage; p++) {
        const btn = document.createElement('button');
        btn.className = `tkb-pagination-btn ${p === tkbCurrentPage ? 'active' : ''}`;
        btn.textContent = p;
        btn.onclick = (() => { const page = p; return () => { if (tkbCurrentPage !== page) { tkbCurrentPage = page; renderTKBFiles(); } }; })();
        paginationContainer.appendChild(btn);
    }

    // Next button
    const nextBtn = document.createElement('button');
    nextBtn.className = `tkb-pagination-btn ${tkbCurrentPage === totalPages ? 'disabled' : ''}`;
    nextBtn.textContent = '»';
    nextBtn.disabled = tkbCurrentPage === totalPages;
    nextBtn.onclick = () => { if (tkbCurrentPage < totalPages) { tkbCurrentPage++; renderTKBFiles(); } };
    paginationContainer.appendChild(nextBtn);
}

function openTKBUploadModal() {
    // If not authenticated, remember intent then ask for password
    if (!isAuthenticated) {
        pendingUploadAction = 'tkb';
        openPasswordModal();
        return;
    }
    const modal = document.getElementById('tkbUploadModal');
    if (modal) {
        modal.classList.remove('hidden');
        modal.setAttribute('tabindex', '-1');
        modal.setAttribute('aria-hidden', 'false');
        lockBodyScroll();
        trapFocus(modal);
    }
}

function closeTKBUploadModal() {
    const modal = document.getElementById('tkbUploadModal');
    if (modal) {
        modal.classList.add('hidden');
        modal.setAttribute('aria-hidden', 'true');
    }
    document.getElementById('tkbUploadForm').reset();
    document.getElementById('tkbFileName').classList.add('hidden');
    releaseFocusTrap();
    unlockBodyScroll();
}

document.getElementById('tkbFile').addEventListener('change', function(e) {
    const fileNameElement = document.getElementById('tkbFileName');
    if (this.files.length > 0) {
        const file = this.files[0];
        const fileSize = (file.size / 1024 / 1024).toFixed(2);
        document.getElementById('tkbFileNameText').textContent = `${file.name} (${fileSize} MB)`;
        fileNameElement.classList.remove('hidden');
    } else {
        fileNameElement.classList.add('hidden');
    }
});

document.getElementById('scoreFile').addEventListener('change', function(e) {
    const fileNameElement = document.getElementById('scoreFileName');
    if (this.files.length > 0) {
        const file = this.files[0];
        const fileSize = (file.size / 1024 / 1024).toFixed(2);
        document.getElementById('scoreFileNameText').textContent = `${file.name} (${fileSize} MB)`;
        fileNameElement.classList.remove('hidden');
    } else {
        fileNameElement.classList.add('hidden');
    }
});

async function uploadTKBFile() {
    const tkbClass = document.getElementById('tkbClass').value;
    const tkbNumber = document.getElementById('tkbNumber').value;
    const file = document.getElementById('tkbFile').files[0];

    if (!tkbClass) {
        showErrorToast('Vui lòng chọn khối lớp');
        return;
    }

    if (!tkbNumber || tkbNumber < 1) {
        showErrorToast('Vui lòng nhập số TKB (>= 1)');
        return;
    }

    if (!file) {
        showErrorToast('Vui lòng chọn file');
        return;
    }

    const allowedTypes = ['application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'application/pdf', 'image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    if (!allowedTypes.includes(file.type)) {
        showErrorToast('Chỉ hỗ trợ file DOCX, PDF, JPG, PNG, WebP');
        return;
    }

    if (file.size > 15 * 1024 * 1024) {
        showErrorToast('File tối đa 15MB');
        return;
    }

    const uploadBtn = document.querySelector('#tkbUploadForm button[type="button"]:last-child');
    const originalBtnText = uploadBtn.innerHTML;
    uploadBtn.disabled = true;
    uploadBtn.textContent = 'Đang upload...';

    try {
        // Use arrayBuffer for faster processing
        const arrayBuffer = await file.arrayBuffer();
        const base64 = btoa(String.fromCharCode(...new Uint8Array(arrayBuffer)));

        const response = await fetch('/.netlify/functions/upload-tkb', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                tkbClass,
                tkbNumber: parseInt(tkbNumber),
                file: 'data:' + file.type + ';base64,' + base64,
                fileName: file.name,
                fileType: file.type
            })
        });

        if (response.ok) {
            showSuccessToast('Upload TKB thành công!');
            closeTKBUploadModal();
            loadTKBFiles();
        } else {
            const err = await response.json();
            showErrorToast(err.message || 'Lỗi upload');
        }
    } catch (e) {
        console.error('Upload TKB error:', e);
        showErrorToast('Lỗi upload file: ' + e.message);
    } finally {
        uploadBtn.innerHTML = originalBtnText;
        uploadBtn.disabled = false;
    }
}

async function deleteTKBFile(fileId) {
    if (!confirm('Bạn chắc chắn muốn xóa file này?')) return;

    try {
        const response = await fetch('/.netlify/functions/delete-tkb', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id: fileId })
        });

        if (response.ok) {
            showSuccessToast('Xóa file thành công!');
            loadTKBFiles();
        } else {
            showErrorToast('Lỗi xóa file');
        }
    } catch (e) {
        showErrorToast('Lỗi: ' + e.message);
    }
}

function updateTKBUploadButtonUI() {
    const uploadTKBBtn = document.getElementById('uploadTKBBtn');
    if (uploadTKBBtn) {
        uploadTKBBtn.style.display = isAuthenticated ? 'inline-block' : 'none';
    }
}
