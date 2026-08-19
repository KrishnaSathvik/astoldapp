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
      if (event.key === 'Escape') closeMenu();
    });
    window.addEventListener('resize', () => {
      if (window.innerWidth > 760) closeMenu();
    }, { passive: true });
  }

  const onScroll = () => header?.classList.toggle('scrolled', window.scrollY > 8);
  onScroll();
  window.addEventListener('scroll', onScroll, { passive: true });

  const currentPath = location.pathname.replace(/\/$/, '') || '/';
  document.querySelectorAll('.links a').forEach(link => {
    const href = new URL(link.href, location.href);
    const linkPath = href.pathname.replace(/\/$/, '') || '/';
    if (linkPath !== '/' && linkPath === currentPath) link.setAttribute('aria-current', 'page');
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
  }, { rootMargin: '0px 0px -7% 0px', threshold: 0.08 });

  reveals.forEach(el => observer.observe(el));
})();
