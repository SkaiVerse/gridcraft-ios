enum Bridge {
    static let script = #"""
    (function () {
      try { Object.defineProperty(navigator, 'platform', { get: function () { return 'MacIntel'; } }); } catch (e) {}

      function banner(t) {
        var d = document.createElement('div');
        d.textContent = 'Error: ' + t;
        d.style.cssText = 'position:fixed;left:0;right:0;bottom:0;z-index:99999;background:#b00020;color:#fff;font:14px sans-serif;padding:8px;';
        d.onclick = function () { d.remove(); };
        (document.body || document.documentElement).appendChild(d);
      }
      window.addEventListener('error', function (e) { banner(e.message); });
      window.addEventListener('unhandledrejection', function (e) { banner(String(e.reason)); });

      document.addEventListener('DOMContentLoaded', function () {
        var m = document.querySelector('meta[name=viewport]');
        if (!m) { m = document.createElement('meta'); m.name = 'viewport'; document.head.appendChild(m); }
        m.content = 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no';
        var s = document.createElement('style');
        s.textContent = 'html,body{margin:0;height:100%;overflow:hidden;overscroll-behavior:none;touch-action:none;-webkit-touch-callout:none;} canvas{touch-action:none;outline:none;}';
        document.head.appendChild(s);
      });

      var blobs = new Map();
      var origCreate = URL.createObjectURL.bind(URL);
      URL.createObjectURL = function (obj) {
        var u = origCreate(obj);
        if (obj instanceof Blob) blobs.set(u, obj);
        return u;
      };

      function send(blob, name) {
        var r = new FileReader();
        r.onload = function () {
          var s = r.result;
          window.webkit.messageHandlers.saveFile.postMessage({ name: name || 'Untitled', data: s.substring(s.indexOf(',') + 1) });
        };
        r.readAsDataURL(blob);
      }

      function handle(a) {
        if (!a || !a.hasAttribute || !a.hasAttribute('download') || !a.href) return false;
        var name = a.getAttribute('download');
        var b = blobs.get(a.href);
        if (b) { send(b, name); return true; }
        if (a.href.indexOf('blob:') === 0 || a.href.indexOf('data:') === 0) {
          fetch(a.href).then(function (r) { return r.blob(); }).then(function (x) { send(x, name); });
          return true;
        }
        return false;
      }

      var origClick = HTMLAnchorElement.prototype.click;
      HTMLAnchorElement.prototype.click = function () {
        if (handle(this)) return;
        return origClick.apply(this, arguments);
      };
      document.addEventListener('click', function (e) {
        var a = e.target && e.target.closest ? e.target.closest('a[download]') : null;
        if (a && handle(a)) e.preventDefault();
      }, true);
    })();
    """#
}
