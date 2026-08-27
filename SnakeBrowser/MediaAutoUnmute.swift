import WebKit

enum MediaAutoUnmute {
    static let scriptSource = """
    (function() {
      if (window.__lorisMediaUnmuteInstalled) { return; }
      window.__lorisMediaUnmuteInstalled = true;

      const applyUnmute = (media) => {
        if (!media || (media.tagName !== 'VIDEO' && media.tagName !== 'AUDIO')) return;
        try {
          media.defaultMuted = false;
          media.removeAttribute('muted');
          media.muted = false;
          if (typeof media.volume === 'number' && media.volume < 0.05) {
            media.volume = 1;
          }
        } catch (e) {}
      };

      const sweep = () => {
        try {
          document.querySelectorAll('video, audio').forEach(applyUnmute);
        } catch (e) {}
      };

      // Keep sites from re-muting every reel (Instagram habit).
      try {
        const desc = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'muted');
        if (desc && desc.set && desc.get) {
          Object.defineProperty(HTMLMediaElement.prototype, 'muted', {
            configurable: true,
            enumerable: true,
            get: function() { return desc.get.call(this); },
            set: function() {
              desc.set.call(this, false);
              try { this.defaultMuted = false; this.volume = 1; } catch (e) {}
            }
          });
        }
      } catch (e) {}

      try {
        const origPlay = HTMLMediaElement.prototype.play;
        HTMLMediaElement.prototype.play = function() {
          applyUnmute(this);
          return origPlay.apply(this, arguments);
        };
      } catch (e) {}

      document.addEventListener('play', (ev) => applyUnmute(ev.target), true);
      document.addEventListener('playing', (ev) => applyUnmute(ev.target), true);
      document.addEventListener('volumechange', (ev) => {
        const m = ev.target;
        if (m && m.muted) applyUnmute(m);
      }, true);

      const startObserver = () => {
        try {
          const root = document.documentElement || document.body;
          if (!root) return;
          const mo = new MutationObserver(() => sweep());
          mo.observe(root, { childList: true, subtree: true });
          sweep();
        } catch (e) {}
      };

      if (document.documentElement) startObserver();
      else document.addEventListener('DOMContentLoaded', startObserver);

      setInterval(sweep, 1200);
    })();
    """

    static func attach(to controller: WKUserContentController) {
        let script = WKUserScript(
            source: scriptSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false,
            in: .page
        )
        controller.addUserScript(script)
    }
}
