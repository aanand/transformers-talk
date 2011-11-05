// Intercept call to sh_highlightDocument
function sh_highlightDocument() {
  $('pre > code').each(function(i, e) {
    var language = this.parentNode.className.match(/\bsh_(\w+)\b/)[1];
    console.log(language);
    this.innerHTML = hljs.highlight(language, $(this).text()).value;
  });
};

