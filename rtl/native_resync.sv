//============================================================================
// native_resync.sv - Video nativo del Aleste LX (720x480, clk_pixel 27 MHz)
// pasado al reloj de video del modo CPC (clk_vid, 80 MHz).
//
// En MiSTer todo el video entra al marco por un solo CLK_VIDEO; el del modo
// CPC va en clk_vid y el nativo en clk_pixel (PLL distinto, asincrono). Este
// modulo hace de puente con un bufer de una linea, enganchado linea a linea a
// la entrada:
//
//   - Escritura (clk_pixel): cada pixel visible de la linea en la RAM.
//   - Lectura (clk_vid): al llegar el inicio de la linea (cruzado con un
//     sincronizador de conmutacion) y tras START_DELAY ciclos, se leen los
//     720 pixeles con un ce de 80/3 = 26,67 MHz.
//
// La lectura (37,5 ns/pixel) es mas lenta que la escritura (37,04 ns/pixel)
// y empieza despues, asi que nunca alcanza a la escritura: basta una linea
// de RAM y el retraso es de unos pocos pixeles. La linea leida dura 27 us y
// la de origen 31,8 us, asi que termina siempre antes de la siguiente.
// Los sincronismos y el vblank se cruzan como niveles (cambian pocas veces
// por linea y con mucho margen) y se registran al ritmo del ce de salida.
//
// Salida con sincronismos positivos, como espera video_mixer.
//============================================================================
`default_nettype none

module native_resync #(
    parameter int H_VISIBLE   = 720,
    parameter int START_DELAY = 16      // ciclos de clk_vid tras detectar la linea
)(
    // Entrada: video nativo, dominio clk_pixel
    input  logic        clk_pixel,
    input  logic [11:0] in_rgb,         // R4G4B4
    input  logic        in_hs,          // activo a nivel bajo (vga_timing, HS_NEG)
    input  logic        in_vs,          // activo a nivel bajo (VS_NEG)
    input  logic        in_hblank,
    input  logic        in_vblank,

    // Salida: dominio clk_vid
    input  logic        clk_vid,
    output logic        ce_pix,
    output logic [7:0]  r,
    output logic [7:0]  g,
    output logic [7:0]  b,
    output logic        hs,             // activos a nivel alto
    output logic        vs,
    output logic        hblank,
    output logic        vblank
);

// ---------------------------------------------------------------------------
// Escritura (clk_pixel)
// ---------------------------------------------------------------------------
(* ramstyle = "no_rw_check" *) logic [11:0] line_ram [0:1023];

logic [9:0] wx = '0;
logic       hb_d = 1'b1;
logic       line_tog = 1'b0;            // cambia al empezar cada linea visible

always_ff @(posedge clk_pixel) begin
    hb_d <= in_hblank;
    if (in_hblank) wx <= '0;
    else begin
        line_ram[wx] <= in_rgb;
        wx <= wx + 10'd1;
    end
    if (hb_d && !in_hblank) line_tog <= ~line_tog;
end

// ---------------------------------------------------------------------------
// Cruce al dominio clk_vid
// ---------------------------------------------------------------------------
logic [2:0] tog_s = '0;
logic [1:0] hs_s = '0, vs_s = '0, vb_s = '1;
always_ff @(posedge clk_vid) begin
    tog_s <= {tog_s[1:0], line_tog};
    hs_s  <= {hs_s[0], ~in_hs};
    vs_s  <= {vs_s[0], ~in_vs};
    vb_s  <= {vb_s[0], in_vblank};
end
wire line_start = tog_s[2] ^ tog_s[1];

// ---------------------------------------------------------------------------
// Lectura (clk_vid)
// ---------------------------------------------------------------------------
logic [5:0]  dly = '0;
logic        active = 1'b0;
logic        line_vb = 1'b1;
logic [9:0]  rx = '0;
logic [1:0]  div = '0;
logic [11:0] q;

always_ff @(posedge clk_vid) q <= line_ram[rx];

always_ff @(posedge clk_vid) begin
    // ce continuo de 80/3 MHz; se recoloca al empezar cada linea para que
    // todas las lineas tengan la misma fase
    div    <= (div == 2'd2) ? 2'd0 : div + 2'd1;
    ce_pix <= (div == 2'd0);

    if (line_start) dly <= START_DELAY[5:0];
    else if (dly != 0) begin
        dly <= dly - 6'd1;
        if (dly == 6'd1) begin
            active  <= 1'b1;
            rx      <= '0;
            div     <= 2'd1;           // primer ce dos ciclos despues: q ya tiene el pixel 0
            line_vb <= vb_s[1];
        end
    end

    if (div == 2'd0) begin
        // un pixel por ce
        hs     <= hs_s[1];
        vs     <= vs_s[1];
        vblank <= line_vb;
        hblank <= ~active;
        r      <= active ? {q[11:8], q[11:8]} : 8'd0;
        g      <= active ? {q[7:4],  q[7:4]}  : 8'd0;
        b      <= active ? {q[3:0],  q[3:0]}  : 8'd0;
        if (active) begin
            if (rx == H_VISIBLE[9:0] - 10'd1) active <= 1'b0;
            else rx <= rx + 10'd1;
        end
    end
end

endmodule

`default_nettype wire
