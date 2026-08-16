module DHT11_Controller (
    input           clk_1M,         // Tín hiệu xung clock 1MHz (chu kỳ 1us)
    input           rst_n,          // Tín hiệu reset mức thấp kích hoạt
    inout           dht11,          // Chân dữ liệu của cảm biến DHT11 (hai chiều)
    output reg [31:0] data_valid,   // Dữ liệu nhiệt độ và độ ẩm đầu ra (phần nguyên và phần thập phân)
    output wire [5:0] data_count_out // Số lượng bit dữ liệu đã nhận được
);

parameter START_READ        = 1000_000;  // Thời gian chờ trước khi bắt đầu đọc dữ liệu (1 giây)
parameter CONTROL_LOW       = 0;        // Trạng thái gửi tín hiệu bắt đầu đọc (xung mức thấp)
parameter CONTROL_LOW_20MS  = 1;        // Trạng thái giữ tín hiệu bắt đầu đọc ở mức thấp trong 20ms
parameter CONTROL_HIGH_13US = 2;        // Trạng thái giải phóng tín hiệu và chờ phản hồi từ DHT11
parameter READ_LOW_83US     = 3;        // Trạng thái chờ xung mức thấp đầu tiên từ DHT11
parameter READ_HIGH_87US    = 4;        // Trạng thái chờ xung mức cao đầu tiên từ DHT11
parameter READ_DATA         = 5;        // Trạng thái đọc 40 bit dữ liệu từ DHT11
parameter KEEP_DELAY        = 6;        // Trạng thái chờ giữa các lần đọc

reg [2:0] cur_state, next_state;     // Trạng thái hiện tại và trạng thái tiếp theo của máy trạng thái
reg [20:0] count_1us;                // Bộ đếm cho các khoảng thời gian 1us
reg [5:0] data_count;                // Bộ đếm số lượng bit dữ liệu đã nhận được
reg [39:0] data_temp;               // Bộ nhớ tạm thời cho 40 bit dữ liệu
reg [4:0] clk_cnt;                 // Bộ đếm không sử dụng
reg us_clear;                     // Cờ xóa bộ đếm 1us
reg state;                        // Trạng thái nội bộ cho việc đọc bit dữ liệu
reg dht_buffer;                   // Bộ đệm để điều khiển chân DHT11
reg dht_d0, dht_d1;               // Thanh ghi để phát hiện cạnh lên và cạnh xuống

/************** Định nghĩa Wire ********************/

wire dht_podge, dht_nedge; // Tín hiệu phát hiện cạnh lên và cạnh xuống
assign dht11 = dht_buffer; // Gán bộ đệm cho chân DHT11
assign dht_podge = ~dht_d1 & dht_d0; // Phát hiện cạnh lên
assign dht_nedge = dht_d1 & ~dht_d0; // Phát hiện cạnh xuống
assign data_count_out = data_count; // Gán số lượng bit dữ liệu cho đầu ra

/************** Bộ đếm 1us ********************/
always @(posedge clk_1M or negedge rst_n) begin
    if (!rst_n) begin
        count_1us <= 21'd0; // Reset bộ đếm
        dht_d0 <= 1'b1;     // Khởi tạo thanh ghi phát hiện cạnh
        dht_d1 <= 1'b1;
    end
    else if (us_clear) begin
        count_1us <= 21'd0; // Xóa bộ đếm khi được yêu cầu
    end
    else begin
        dht_d0 <= dht11;     // Dịch giá trị chân DHT11 để phát hiện cạnh
        dht_d1 <= dht_d0;
        count_1us <= count_1us + 1'b1; // Tăng bộ đếm
    end
end

/************** Máy trạng thái ********************/
always @(posedge clk_1M or negedge rst_n) begin
    if (!rst_n)
        cur_state <= CONTROL_LOW; // Reset về trạng thái ban đầu
    else
        cur_state <= next_state; // Cập nhật trạng thái hiện tại
end

always @(posedge clk_1M or negedge rst_n) begin
    if(!rst_n) begin
        next_state <= CONTROL_LOW; // Reset về trạng thái ban đầu
        dht_buffer <= 1'bz;        // Khởi tạo chân DHT11 ở trạng thái trở kháng cao
        state      <= 1'b0;        // Reset trạng thái đọc bit dữ liệu
        us_clear   <= 1'b0;        // Reset cờ xóa bộ đếm 1us
        data_temp  <= 40'd0;       // Reset bộ nhớ dữ liệu
        data_count <= 6'd0;        // Reset bộ đếm bit dữ liệu
    end
    else begin
        case (cur_state)
            CONTROL_LOW: begin
                if(count_1us < START_READ) begin
                    dht_buffer <= 1'bz; // Giữ chân ở trạng thái trở kháng cao
                    us_clear   <= 1'b0; // Không xóa bộ đếm
                end else begin
                    next_state <= CONTROL_LOW_20MS; // Chuyển sang trạng thái tiếp theo
                    us_clear   <= 1'b1; // Xóa bộ đếm
                end
            end

            CONTROL_LOW_20MS: begin
                if(count_1us < 20000) begin // Xung mức thấp 20ms
                    dht_buffer <= 1'b0; // Kéo chân xuống mức thấp
                    us_clear   <= 1'b0; // Không xóa bộ đếm
                end else begin
                    next_state <= CONTROL_HIGH_13US; // Chuyển sang trạng thái tiếp theo
                    dht_buffer <= 1'bz; // Giải phóng chân
                    us_clear   <= 1'b1; // Xóa bộ đếm
                end
            end

            CONTROL_HIGH_13US: begin
                if (count_1us < 20) begin // Chờ phản hồi từ DHT11
                    us_clear <= 1'b0; // Không xóa bộ đếm
                    if (dht_nedge) begin // Phát hiện cạnh xuống của phản hồi DHT11
                        next_state <= READ_LOW_83US; // Chuyển sang trạng thái tiếp theo
                        us_clear   <= 1'b1; // Xóa bộ đếm
                    end
                end else begin
                    next_state <= KEEP_DELAY; // Nếu không có phản hồi, chuyển sang trạng thái chờ.
                end
            end

            READ_LOW_83US: begin
                if (dht_podge) // Chờ cạnh lên
                    next_state <= READ_HIGH_87US; // Chuyển sang trạng thái tiếp theo
            end

            READ_HIGH_87US: begin
                if (dht_nedge) begin // Chờ cạnh xuống
                    next_state <= READ_DATA; // Chuyển sang trạng thái đọc dữ liệu
                    us_clear   <= 1'b1; // Xóa bộ đếm
                end else begin
                    data_count <= 6'd0;
                    data_temp <= 40'd0;
                    state <= 1'b0;
                end
            end

            READ_DATA: begin
                case (state)
                    0: begin
                        if (dht_podge) begin
                            state <= 1'b1;
                            us_clear <= 1'b1;
                        end else begin
                            us_clear <= 1'b0;
                        end
                    end
                    1: begin
                        if (dht_nedge) begin
                            data_count <= data_count + 1'b1;
                            state <= 1'b0;
                            us_clear <= 1'b1;
                            if (count_1us < 60)
                                data_temp <= {data_temp[38:0],1'b0}; // 0
                            else
                                data_temp <= {data_temp[38:0],1'b1}; // 1
                        end else begin
                            us_clear <= 1'b0;
                        end
                    end
                endcase

                if(data_count == 40) begin
                    next_state <= KEEP_DELAY;
                end
            end

            KEEP_DELAY: begin
                if (count_1us < 2000_000)
                    us_clear <= 1'b0;
                else begin
                    next_state <= CONTROL_LOW_20MS;
                    us_clear <= 1'b1;
                end
            end

            default: next_state <= CONTROL_LOW;
        endcase
    end
end

/************** Kiểm tra Checksum ********************/
always @(posedge clk_1M or negedge rst_n) begin
    if (!rst_n) begin
        data_valid <= 32'd0;
    end
    else if (data_count == 40) begin
        reg [7:0] humidity_int, humidity_dec;
        reg [7:0] temperature_int, temperature_dec;
        reg [7:0] checksum, checksum_calc;

        humidity_int     = data_temp[39:32];
        humidity_dec     = data_temp[31:24];
        temperature_int = data_temp[23:16];
        temperature_dec = data_temp[15:8];
        checksum         = data_temp[7:0];

        checksum_calc = humidity_int + humidity_dec + temperature_int + temperature_dec;

        if (checksum == checksum_calc) begin
            data_valid <= data_temp[39:8];
        end
        else begin
            data_valid <= 32'd0;
        end
    end
end

endmodule