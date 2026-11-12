// 編輯器內的流程圖與 PDF 匯出共用的繪圖函式。
let diagramCounter = 0;

async function diagramSVG(source, theme) {
  mermaid.initialize({
    startOnLoad: false,
    securityLevel: 'strict',
    theme: 'base',
    themeVariables: Object.assign({
      fontFamily: '-apple-system, "PingFang TC", "Helvetica Neue", sans-serif',
      fontSize: '14px',
    }, theme),
    flowchart: { curve: 'basis', padding: 14, nodeSpacing: 44, rankSpacing: 48, useMaxWidth: false },
  });
  const id = 'diagram' + (++diagramCounter);
  try {
    const { svg } = await mermaid.render(id, source);
    return svg;
  } finally {
    // 語法錯誤時 Mermaid 會把錯誤圖示留在頁面上。
    document.querySelectorAll('#d' + id + ', #' + id).forEach((node) => node.remove());
  }
}

// 把圖畫進 #host，回傳實際尺寸讓原生端裁切成 PDF。
async function renderDiagram(source, theme) {
  const host = document.getElementById('host');
  host.innerHTML = await diagramSVG(source, theme);
  const svg = host.querySelector('svg');
  const box = svg.viewBox.baseVal;
  if (box && box.width > 0) {
    svg.setAttribute('width', box.width);
    svg.setAttribute('height', box.height);
    svg.style.maxWidth = 'none';
  }
  const rect = svg.getBoundingClientRect();
  return { width: rect.width, height: rect.height };
}

// PDF 匯出：填入文件內容，並把 mermaid 程式碼區塊換成圖。
async function fill(html, theme) {
  const content = document.getElementById('content');
  content.innerHTML = html;
  for (const code of content.querySelectorAll('pre > code.language-mermaid')) {
    const figure = document.createElement('figure');
    figure.className = 'diagram';
    try {
      figure.innerHTML = await diagramSVG(code.textContent, theme);
      const svg = figure.querySelector('svg');
      const box = svg.viewBox.baseVal;
      if (box && box.width > 0) {
        svg.setAttribute('width', box.width);
        svg.setAttribute('height', box.height);
      }
      code.parentElement.replaceWith(figure);
    } catch (error) {
      // 畫不出來就保留原本的文字，不讓整份文件匯出失敗。
    }
  }
  for (const link of content.querySelectorAll('a')) {
    link.setAttribute('rel', 'noreferrer');
  }
  await document.fonts.ready;
  return true;
}
