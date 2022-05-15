wand = [2, 2, 2];

sds011 = [71, 71, 28];
sds011_anluft = [10, wand.y, 10];
sds011_anluft_offset = [wand.x + 15, 0, wand.z + 10];

esp8266 = [38, 71, 13];
esp8266_usb = [wand.x, 20, 13];
esp8266_usb_offset = [0, wand.y + 5, wand.z];

difference() {
    cube(sds011 + wand + [wand.x, 0, wand.z]);
    translate(wand) cube(sds011);
    translate(sds011_anluft_offset) cube(sds011_anluft);
}

translate([0, 0, wand.z + sds011.z]) difference() {
    cube(esp8266 + wand + [wand.x, 0, wand.z]);
    translate(wand) cube(esp8266);
    translate(esp8266_usb_offset) cube(esp8266_usb);
}