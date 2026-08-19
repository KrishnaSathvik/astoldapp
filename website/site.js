(() => {
  const header = document.querySelector('.site');
  const toggle = document.querySelector('.navtoggle');
  const links = document.querySelector('.links');

  const closeMenu = () => {
    document.body.classList.remove('menu-open');
    if (toggle) {
      toggle.setAttribute('aria-expanded', 'false');
      toggle.setAttribute('aria-label', 'Open menu');
    }
  };

  if (toggle && links) {
    toggle.addEventListener('click', () => {
      const open = document.body.classList.toggle('menu-open');
      toggle.setAttribute('aria-expanded', String(open));
      toggle.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
    });
    links.addEventListener('click', event => {
      if (event.target.closest('a')) closeMenu();
    });
    document.addEventListener('keydown', event => {
      if (event.key === 'Escape' && document.body.classList.contains('menu-open')) {
        closeMenu();
        toggle.focus();
      }
    });
    // A tap outside the sheet should dismiss it the way any iOS menu would.
    document.addEventListener('pointerdown', event => {
      if (!document.body.classList.contains('menu-open')) return;
      if (event.target.closest('.links') || event.target.closest('.navtoggle')) return;
      closeMenu();
    });
    window.addEventListener('resize', () => {
      if (window.innerWidth > 760) closeMenu();
    }, { passive: true });
  }

  const onScroll = () => header?.classList.toggle('scrolled', window.scrollY > 8);
  onScroll();
  window.addEventListener('scroll', onScroll, { passive: true });

  // `/foo`, `/foo.html` and `/foo/` are the same page; `/index` is the root.
  const normalise = path => {
    const p = path.replace(/\.html$/, '').replace(/\/$/, '') || '/';
    return p === '/index' ? '/' : p;
  };
  const currentPath = normalise(location.pathname);
  document.querySelectorAll('.links a').forEach(link => {
    const url = new URL(link.href, location.href);
    // An in-page jump like `#writing` is not a different page — marking it
    // aria-current would tell a screen reader the wrong thing.
    if (url.hash) return;
    if (normalise(url.pathname) === currentPath) link.setAttribute('aria-current', 'page');
  });

  const reveals = document.querySelectorAll('.reveal');
  if (!('IntersectionObserver' in window)) {
    reveals.forEach(el => el.classList.add('in'));
    return;
  }

  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('in');
        observer.unobserve(entry.target);
      }
    });
  }, { rootMargin: '0px 0px -6% 0px', threshold: 0.06 });

  reveals.forEach(el => observer.observe(el));
})();
