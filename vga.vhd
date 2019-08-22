library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.STD_LOGIC_UNSIGNED.all;

library vga_types;
use vga_types.vga_config.all;

library generic_types;
use generic_types.graphics.all;

entity vga is
port(
    system_clock : in STD_LOGIC;
    red : out STD_LOGIC_VECTOR(3 downto 0);
    green : out STD_LOGIC_VECTOR(3 downto 0);
    blue : out STD_LOGIC_VECTOR(3 downto 0);
    vsync : out STD_LOGIC;
    hsync: out STD_LOGIC;
    count_button : in STD_LOGIC;
    reset_button : in STD_LOGIC;
    display_leds : out STD_LOGIC_VECTOR(3 downto 0)
);
end vga;

architecture main of vga is

-- Clock Wizard component
component clk_wiz_0
port(
  CLK_IN1 : in std_logic;
  CLK_OUT1 : out std_logic
);
end component;

-- VGA Controller component
component vga_controller is
generic(
    config : in vga_config
);
port(
    clock: in STD_LOGIC;
    hsync : out STD_LOGIC;
    vsync : out STD_LOGIC;
    draw_point : out point_2d
);
end component;

-- Button Debouncer component
component button_debouncer is
generic(
    max_button_count : natural := 10000000
);
port(
    clock: in STD_LOGIC;
    button_state : in STD_LOGIC;
    button_press : out STD_LOGIC
);
end component;

-- Clock that drives the VGA Controller
signal pixel_clock : STD_LOGIC;

-- Position of the drawing beam
signal draw_point : point_2d := point_2d_init;

signal count_button_press : STD_LOGIC;
signal reset_button_press : STD_LOGIC;
signal count_value : STD_LOGIC_VECTOR(3 downto 0) := "0000";

begin
    clk_div_inst : clk_wiz_0
    port map(
        CLK_IN1 => system_clock,
        CLK_OUT1 => pixel_clock
    );

    vga_controller_inst : vga_controller
    generic map(
        -- 1280x1024@60 Hz
        config => (
            hfp_length => 48,
            hsync_length => 112,
            hbp_length => 248,
            hview_length => 1280,
            vfp_length => 1,
            vsync_length => 3,
            vbp_length => 38,
            vview_length => 1024
        )
    )
    port map(
        clock => pixel_clock,
        hsync => hsync,
        vsync => vsync,
        draw_point => draw_point
    );

    count_button_debouncer : button_debouncer
    port map(
        clock => system_clock,
        button_state => count_button,
        button_press => count_button_press
    );

    reset_button_debouncer : button_debouncer
    port map(
        clock => system_clock,
        button_state => reset_button,
        button_press => reset_button_press
    );

    process(pixel_clock)
    function is_point_in_circle(
            point : in point_2d;
            center : in point_2d;
            radius : in integer)
        return boolean is
        variable x_diff : integer;
        variable y_diff : integer;
    begin
        x_diff := point.x - center.x;
        y_diff := point.y - center.y;
        if (x_diff ** 2 + y_diff ** 2) < (radius ** 2) then
            return true;
        else
            return false;
        end if;
    end function is_point_in_circle;

    impure function draw_circle(
            center : in point_2d;
            radius : in integer;
            r : in STD_LOGIC_VECTOR(3 downto 0);
            g : in STD_LOGIC_VECTOR(3 downto 0);
            b : in STD_LOGIC_VECTOR(3 downto 0))
        return boolean is
    begin
        if is_point_in_circle(draw_point, center, radius) then
            red <= r;
            green <= g;
            blue <= b;
            return true;
        else
            return false;
        end if;
    end function draw_circle;

    function is_point_in_rectangle(
            point : in point_2d;
            top_left_point : in point_2d;
            bottom_right_point : in point_2d)
        return boolean is
    begin
        if point.x > top_left_point.x and point.x < bottom_right_point.x and
                point.y > top_left_point.y and point.y < bottom_right_point.y then
            return true;
        else
            return false;
        end if;
    end function is_point_in_rectangle;

    impure function draw_rectangle(
            top_left_point : in point_2d;
            bottom_right_point : in point_2d;
            r : in STD_LOGIC_VECTOR(3 downto 0);
            g : in STD_LOGIC_VECTOR(3 downto 0);
            b : in STD_LOGIC_VECTOR(3 downto 0))
        return boolean is
    begin
        if is_point_in_rectangle(draw_point, top_left_point, bottom_right_point) then
            red <= r;
            green <= g;
            blue <= b;
            return true;
        else
            return false;
        end if;
    end function draw_rectangle;

    variable should_blank : boolean;
    begin
        if rising_edge(pixel_clock) then
            -- Blank everything by default
            should_blank := true;

            if draw_circle((320, 380), 100, "1111", "1111", "1111") then
                should_blank := false;
            end if;

            if draw_rectangle((400, 100), (500, 400), "1100", "0011", "0000") then
                should_blank := false;
            end if;

            if should_blank then
                red <= "0000";
                green <= "0000";
                blue <= "0000";
            end if;
        end if;
    end process;

    process(system_clock)
    begin
        if rising_edge(system_clock) then
            if count_button_press = '1' then
                if count_value = "1111" then
                    count_value <= "0000";
                else
                    count_value <= count_value + '1';
                end if;
            end if;

            if reset_button_press = '1' then
                count_value <= "0000";
            end if;
        end if;
    end process;

    display_leds <= count_value;
end main;
