// Intercept call to sh_highlightDocument
function sh_highlightDocument() {
  $('pre > code').each(function(i, e) {
    if (!this.parentNode.className) return;
    var language = this.parentNode.className.match(/\bsh_(\w+)\b/)[1];
    this.innerHTML = hljs.highlight(language, $(this).text()).value;

    // Fix highlighting of Ruby 1.9 symbol hash key style
    $('.symbol', this).each(function(i, e) {
      if (e.previousSibling.className === 'identifier') {
        e.previousSibling.className = 'symbol';
      }
    })
  });
};

