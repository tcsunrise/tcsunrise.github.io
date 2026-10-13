// Collapse long code blocks by default, with an expand/collapse toggle
document.addEventListener('DOMContentLoaded', () => {
  const COLLAPSED_HEIGHT = 18 * 16;

  document.querySelectorAll('.content div.highlighter-rouge:not(.language-mermaid)').forEach((block) => {
    const code = block.querySelector('.highlight');
    if (!code || code.scrollHeight <= COLLAPSED_HEIGHT + 64) return;

    const source = block.querySelector('.rouge-code') || code;
    const lines = source.textContent.replace(/\n$/, '').split('\n').length;
    const expandText = `展开全部（共 ${lines} 行）`;

    const toggle = document.createElement('button');
    toggle.type = 'button';
    toggle.className = 'code-toggle';
    toggle.textContent = expandText;
    toggle.addEventListener('click', () => {
      // Expanding keeps the block top in place (grows downward);
      // collapsing keeps the toggle button in place
      const anchor = block.classList.contains('code-collapsed') ? block : toggle;
      const before = anchor.getBoundingClientRect().top;
      const collapsed = block.classList.toggle('code-collapsed');
      toggle.textContent = collapsed ? expandText : '收起';
      window.scrollBy({ top: anchor.getBoundingClientRect().top - before, behavior: 'instant' });
    });

    block.classList.add('code-collapsed');
    block.appendChild(toggle);
  });
});
