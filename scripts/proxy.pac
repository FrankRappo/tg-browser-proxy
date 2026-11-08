// BT-Proxy PAC: only Telegram via local SOCKS5 (plink), everything else DIRECT
function FindProxyForURL(url, host) {
  if (dnsDomainIs(host, ".telegram.org") ||
      dnsDomainIs(host, ".t.me") ||
      dnsDomainIs(host, ".telegram.me") ||
      dnsDomainIs(host, ".telesco.pe") ||
      dnsDomainIs(host, ".telegram.dog")) {
    return "SOCKS5 127.0.0.1:1080";
  }
  return "DIRECT";
}
