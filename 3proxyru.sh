#!/bin/bash

set -e  # Dừng thực thi tập lệnh khi có bất kỳ lỗi nào 

# Hàm kiểm tra thành công của việc thực thi lệnh 
check_success() {
    if [ $1 -ne 0 ]; then
        echo "Ошибка: $2"
        exit 1
    fi
}

# Hàm xóa 3proxy 
remove_3proxy() {
    echo "Đang xóa 3proxy..."

    #  Dừng và vô hiệu hóa dịch vụ 3proxy 
    sudo systemctl stop 3proxy || true
    check_success $? "Không dừng được dịch vụ 3proxy"
    sudo systemctl disable 3proxy || true
    check_success $? "Không thể vô hiệu hóa dịch vụ 3proxy"

    # Xóa các tệp 3proxy 
    sudo rm -f /usr/local/bin/3proxy
    sudo rm -rf /usr/local/3proxy
    sudo rm -f /usr/lib/systemd/system/3proxy.service
    sudo rm -rf /var/log/3proxy

    # Tải lại daemon systemd 
    sudo systemctl daemon-reload

    echo "Đã xóa 3proxy thành công."
    exit 0
}

# Yêu cầu chọn hành động
echo "Chọn hành động:"
echo "1. Cài đặt 3proxy"
echo "2. Xóa 3proxy"
read -p "Nhập số lựa chọn (1 hoặc 2): " action

case $action in
    1)
        echo "Bạn đã chọn cài đặt 3proxy."
        ;;
    2)
        remove_3proxy
        ;;
    *)
        echo "Lựa chọn không hợp lệ. Tập lệnh đã kết thúc."
        exit 1
        ;;
esac

# Cập nhật và cài đặt các gói cần thiết 
sudo apt update && apt upgrade -y
sudo apt install -y build-essential git ca-certificates curl
check_success $? "Không thể cài đặt các gói cần thiết"

# Sao chép kho lưu trữ 3proxy 
git clone https://github.com/z3APA3A/3proxy.git
cd 3proxy
check_success $? "Không thể sao chép kho lưu trữ 3proxy"

# Xây dựng và cài đặt 3proxy 
ln -s Makefile.Linux Makefile
make
sudo make install
check_success $? "Không thể xây dựng và cài đặt 3proxy"

echo "Đang tạo được thư mục cho 3proxy..."
sudo mkdir -p /usr/local/3proxy/bin/
check_success $? "Không tạo được thư mục cho 3proxy"

echo "Đang sao chép 3proxy..."
sudo cp ./bin/3proxy /usr/local/bin/
check_success $? "Không thể sao chép 3proxy"

echo "Đang tạo thư mục nhật ký..."
sudo mkdir -p /var/log/3proxy
check_success $? "Không tạo được thư mục nhật k"

# Đường dẫn đến tệp cấu hình
CONFIG_FILE="/usr/local/3proxy/conf/3proxy.cfg"

# Проверка, существует ли файл конфигурации
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Không tìm thấy tệp cấu hình. Đang tạo tệp trống mới...."

    # Tạo thư mục để cấu hình nếu nó không tồn tại 
    sudo mkdir -p /usr/local/3proxy/conf

    # Tạo tệp cấu hình trống 
    sudo touch "$CONFIG_FILE"
    check_success $? "Không tạo được tệp $CONFIG_FILE"

    #  Đặt quyền cho tệp (tùy chọn)
    sudo chmod 644 "$CONFIG_FILE"
    check_success $? "Không thể thiết lập quyền cho $CONFIG_FILE"
else
    echo "Tệp cấu hình đã tồn tại."
fi

# Thiết lập quyền 
sudo chown -R $USER:$USER /usr/local/3proxy
sudo chmod 755 /usr/local/bin/3proxy
sudo chmod 755 /var/log/3proxy
check_success $? "Không thể cấu hình quyền truy cập"

# Yêu cầu chọn loại cài đặt
echo "Выберите тип установки:"
echo "1. Cho phép"
echo "2. Không cho phép"
echo "3. Không có quyền hạn cho một số IP nhất định"
read -p "Nhập số lựa chọn (1, 2 hoặc 3): " choice

# Yêu cầu cổng
while true; do
    read -p "Nhập cổng (1024-65535):  " port
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1024 ] && [ "$port" -le 65535 ]; then
        break
    else
        echo "Cổng không hợp lệ. Hãy thử lại."
    fi
done

# Tạo một tập tin cấu hình tùy thuộc vào lựa chọn
case $choice in
    1)
        # Yêu cầu dữ liệu người dùng
        read -p "Nhập tên người dùng:" username
        while true; do
            read -s -p "Nhập mật khẩu: " password
            echo
            read -s -p "Xác nhận mật khẩu:" password2
            echo
            [ "$password" = "$password2" ] && break
            echo "Mật khẩu không khớp. Hãy thử lại"
        done

        cat << EOF | sudo tee /usr/local/3proxy/conf/3proxy.cfg
nserver 8.8.8.8
nserver 8.8.4.4

log /var/log/3proxy/3proxy-%y%m%d.log D
rotate 60

users $username:CL:$password
auth strong
allow *

proxy -p$port
EOF
        ;;
    2)
        cat << EOF | sudo tee /usr/local/3proxy/conf/3proxy.cfg
nserver 8.8.8.8
nserver 8.8.4.4

log /var/log/3proxy/3proxy-%y%m%d.log D
rotate 60

allow *

proxy -p$port
EOF
        ;;
3)
    read -p "Nhập địa chỉ IP được phép, phân tách bằng dấu phẩy không có khoảng trắng: " allowed_ips

    # Chuyển đổi địa chỉ IP sang định dạng cấu hình
    IFS=',' read -ra ADDR <<< "$allowed_ips"

    # Nối các địa chỉ IP thành một dòng
    allow_ips="${ADDR[*]}"

    # Tạo tập tin cấu hình
    cat << EOF | sudo tee /usr/local/3proxy/conf/3proxy.cfg
nserver 8.8.8.8
nserver 8.8.4.4

log /var/log/3proxy/3proxy-%y%m%d.log D
rotate 60

allow * $allow_ips
deny * * *

proxy -p$port -i0.0.0.0 -e0.0.0.0
EOF
        ;;
    *)
        echo "Lựa chọn không hợp lệ. Đã chấm dứt tập lệnh."
        exit 1
        ;;
esac
check_success "Không tạo được tệp cấu hình"

# Tạo tệp dịch vụ systemd
cat << EOF | sudo tee /usr/lib/systemd/system/3proxy.service
[Unit]
Description=3proxy tiny proxy server
Documentation=man:3proxy(1)
After=network.target

[Service]
Environment=CONFIGFILE=/usr/local/3proxy/conf/3proxy.cfg
ExecStart=/usr/local/bin/3proxy \${CONFIGFILE}
ExecReload=/bin/kill -SIGUSR1 \$MAINPID
KillMode=process
Restart=on-failure
RestartSec=60s
LimitNOFILE=65536
LimitNPROC=32768
RuntimeDirectory=3proxy

[Install]
WantedBy=multi-user.target
Alias=3proxy.service
EOF
check_success "Không tạo được tệp dịch vụ systemd"

# Khởi động lại daemon systemd và khởi động dịch vụ 3proxy
sudo systemctl daemon-reload
sudo systemctl enable 3proxy
sudo systemctl start 3proxy
check_success "Không khởi động được dịch vụ 3proxy"

echo "Quá trình cài đặt đã hoàn tất thành công."
echo "Cài đặt 3proxy:"
echo "Cổng: $port"
echo "Tệp cấu hình: /usr/local/3proxy/conf/3proxy.cfg"
echo "Tệp nhật ký: /var/log/3proxy/"
echo "Docker đã được cài đặt và người dùng hiện tại đã được thêm vào nhóm docker."
echo "Bạn có thể cần khởi động lại hoặc đăng xuất để áp dụng các thay đổi nhóm."
