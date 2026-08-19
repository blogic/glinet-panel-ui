# glinet-panel-ui

The front panel interface for the GL.iNet BE10000 and BE14000: a 320x240 DRM
display with a capacitive touchscreen, driven from ucode.

It shows an idle clock with the weather and the link rate, then a set of pages
the user swipes between: traffic, wireless, the networks and their switches, the
radios, QR codes to join them, the clients, the interfaces and their addresses,
the ports, the system gauges, brightness and reboot. Rows open sub pages with
the detail behind them.

Written against [ucode-mod-lvgl](https://github.com/blogic/ucode-mod-lvgl).

## Screens

Every picture below is the panel itself at 320x240, taken with
ubus call lvgl screenshot.

<table>
<tr>
<td align="center"><img src="screenshots/idle.png" width="240"><br><sub>Idle</sub></td>
<td align="center"><img src="screenshots/pin.png" width="240"><br><sub>PIN</sub></td>
<td align="center"><img src="screenshots/traffic.png" width="240"><br><sub>Traffic</sub></td>
</tr>
<tr>
<td align="center"><img src="screenshots/weather.png" width="240"><br><sub>Weather</sub></td>
<td align="center"><img src="screenshots/wifi.png" width="240"><br><sub>Wi-Fi</sub></td>
<td align="center"><img src="screenshots/wifi-ssid.png" width="240"><br><sub>Wi-Fi, one network</sub></td>
</tr>
<tr>
<td align="center"><img src="screenshots/qrcodes.png" width="240"><br><sub>QR codes</sub></td>
<td align="center"><img src="screenshots/ports.png" width="240"><br><sub>Ports</sub></td>
<td align="center"><img src="screenshots/system.png" width="240"><br><sub>System</sub></td>
</tr>
</table>

## Packaging

The OpenWrt package is glinet-panel-ui in
[feed-blogic](https://github.com/blogic/feed-blogic).

## Licence

The application is GPL-2.0-only; LICENSE.txt carries the text.
