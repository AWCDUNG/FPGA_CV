module Top_Module (
    input wire clk,       // Xung clock chính của hệ thống
    input wire rst_n,     // Tín hiệu reset active-low
    inout wire dht11,     // Chân dữ liệu giao tiếp với cảm biến DHT11 (inout vì hai chiều)
    output wire lcd_rs,   // Tín hiệu Register Select cho LCD
    output wire lcd_e,    // Tín hiệu Enable cho LCD
    output wire [7:0] lcd_db, // Bus dữ liệu 8-bit cho LCD
    output wire [7:0] led_hum, // LED hiển thị phần nguyên độ ẩm
    output wire [5:0] led_temp // LED hiển thị phần nguyên nhiệt độ
);

    wire [31:0] data_valid; // Tín hiệu dữ liệu hợp lệ từ DHT11 (nhiệt độ và độ ẩm)
    wire [15:0] temperature; // Giá trị nhiệt độ từ DHT11
    wire [15:0] humidity;    // Giá trị độ ẩm từ DHT11
    wire clk_1MHz_out;     // Xung clock 1MHz tạo từ module Clock_1MHz

    // Tạo xung clock 1MHz từ xung clock đầu vào (50MHz)
    Clock_1MHz CLK1MHZ (
        .clk(clk),           // Kết nối xung clock đầu vào
        .rst_n(rst_n),       // Kết nối tín hiệu reset
        .clk_1M(clk_1MHz_out) // Xuất xung clock 1MHz
    );

    // Module điều khiển giao tiếp với cảm biến DHT11
    DHT11_Controller dht11_ctrl (
        .clk_1M(clk_1MHz_out), // Kết nối xung clock 1MHz
        .rst_n(rst_n),         // Kết nối tín hiệu reset
        .dht11(dht11),         // Kết nối chân dữ liệu DHT11
        .data_valid(data_valid) // Kết nối tín hiệu dữ liệu hợp lệ từ DHT11
    );

    // Phân tách dữ liệu hợp lệ từ DHT11 thành nhiệt độ và độ ẩm
    assign humidity    = data_valid[31:16]; // Lấy 16 bit độ ẩm từ data_valid
    assign temperature = data_valid[15:0];  // Lấy 16 bit nhiệt độ từ data_valid

    // Module điều khiển hiển thị dữ liệu lên LCD
    LCD_Controller lcd_ctrl (
        .clk(clk),           // Kết nối xung clock chính
        .temperature(temperature), // Kết nối giá trị nhiệt độ
        .humidity(humidity),    // Kết nối giá trị độ ẩm
        .lcd_rs(lcd_rs),       // Kết nối tín hiệu RS cho LCD
        .lcd_e(lcd_e),        // Kết nối tín hiệu E cho LCD
        .lcd_db(lcd_db)       // Kết nối bus dữ liệu LCD
    );

    // Xuất dữ liệu độ ẩm (phần nguyên) ra LED để kiểm tra
    assign led_hum = data_valid[31:24];

    // Xuất dữ liệu nhiệt độ(phần nguyên) ra LED để kiểm tra
    assign led_temp = data_valid[13:8];

endmodule