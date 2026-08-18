// As Told — shared site behavior: sticky-header hairline, mobile menu, scroll reveals.
(function () {
  var head = document.getElementById('site-head');
  if (head) {
    var onScroll = function () { head.classList.toggle('scrolled', window.scrollY > 8); };
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
  }

  // ---- mobile menu ----
  var toggle = document.getElementById('nav-toggle');
  var panel = document.getElementById('nav-links');
  if (toggle && panel) {
    var setOpen = function (open) {
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
      toggle.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
      if (open) { panel.setAttribute('data-open', ''); }
      else { panel.removeAttribute('data-open'); }
    };
    toggle.addEventListener('click', function () {
      setOpen(toggle.getAttribute('aria-expanded') !== 'true');
    });
    // close after choosing a destination
    panel.addEventListener('click', function (e) {
      if (e.target.closest('a')) { setOpen(false); }
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') {
        setOpen(false); toggle.focus();
      }
    });
    // click outside dismisses
    document.addEventListener('click', function (e) {
      if (toggle.getAttribute('aria-expanded') !== 'true') return;
      if (!e.target.closest('#nav-links') && !e.target.closest('#nav-toggle')) setOpen(false);
    });
    // never leave the panel stuck open when it turns back into a desktop bar
    var desktop = window.matchMedia('(min-width: 861px)');
    var onChange = function (m) { if (m.matches) setOpen(false); };
    if (desktop.addEventListener) desktop.addEventListener('change', onChange);
    else if (desktop.addListener) desktop.addListener(onChange);
  }

  // ---- scroll reveals ----
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var els = document.querySelectorAll('.reveal');
  if (reduce || !('IntersectionObserver' in window)) {
    els.forEach(function (e) { e.classList.add('in'); });
    return;
  }
  var io = new IntersectionObserver(function (entries) {
    entries.forEach(function (en) {
      if (en.isIntersecting) { reveal(en.target); }
    });
  }, { threshold: 0.14, rootMargin: '0px 0px -8% 0px' });
  els.forEach(function (e) { io.observe(e); });

  function reveal(el) { el.classList.add('in'); io.unobserve(el); }

  // Safety net: a fast flick, a restored scroll position, or a deep #hash can skip
  // the observer. Anything at or above the fold gets revealed regardless, so content
  // can never be left stranded at opacity:0.
  var pending = els.length, ticking = false;
  function sweep() {
    ticking = false;
    pending = 0;
    els.forEach(function (e) {
      if (e.classList.contains('in')) return;
      if (e.getBoundingClientRect().top < window.innerHeight * 0.92) reveal(e);
      else pending++;
    });
    if (!pending) {
      window.removeEventListener('scroll', onSweep);
      window.removeEventListener('resize', onSweep);
    }
  }
  function onSweep() {
    if (ticking) return;
    ticking = true;
    window.requestAnimationFrame(sweep);
  }
  window.addEventListener('scroll', onSweep, { passive: true });
  window.addEventListener('resize', onSweep);
  window.addEventListener('load', sweep);
  window.addEventListener('pageshow', sweep);
  sweep();
})();
