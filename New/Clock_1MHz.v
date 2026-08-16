// Tạo bộ chia xung clock từ 50MHz xuống 1MHz
module Clock_1MHz(clk, rst_n, clk_1M);
    // dây tín hiệu clock đầu vào và reset
    input clk, rst_n;
    // xung clock đầu ra sau khi chia tỷ lệ xuống 1MHz
    output clk_1M;
    // thanh ghi clk_cnt để đếm từ 1 đến 25 -> tạo xung clock 1MHz độ rộng xung 50%
    reg [4:0] clk_cnt;
    reg clk_1M;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 5'd0; // Reset bộ đếm về 0 khi tín hiệu reset kích hoạt (low)
            clk_1M <= 1'b0; // Reset xung clock đầu ra về 0
        end
        else if (clk_cnt < 5'd24) begin
            clk_cnt <= clk_cnt + 1'b1; // Tăng bộ đếm lên 1 nếu nó nhỏ hơn 24
        end
        else begin
            clk_cnt <= 5'd0; // Reset bộ đếm về 0 khi nó đạt 24
            clk_1M <= ~clk_1M; // Đảo trạng thái xung clock đầu ra
        end
    end
endmodule