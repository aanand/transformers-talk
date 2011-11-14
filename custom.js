// Intercept call to sh_highlightDocument
function sh_highlightDocument() {
  $('pre > code').highlight();
}

$.fn.highlight = function(lang) {
  this.each(function(i, e) {
    if (!lang && !this.parentNode.className) return;
    var language = lang || this.parentNode.className.match(/\bsh_(\w+)\b/)[1];
    this.innerHTML = hljs.highlight(language, $(this).text()).value;

    // Fix highlighting of Ruby 1.9 symbol hash key style
    $('.symbol', this).each(function(i, e) {
      if (e.previousSibling && e.previousSibling.className === 'identifier') {
        e.previousSibling.className = 'symbol';
      }
    })
  });

  return this;
};

$.fn.stepThrough = function() {
  this.each(function(i, e) {
    var slide        = $(e),
        pre          = slide.find('pre'),
        originalPre  = pre.clone();

    slide.addClass('step-through');
    slide.bind('showoff:next', function(event) { doStep(event, +1) });
    slide.bind('showoff:prev', function(event) { doStep(event, -1) });

    doHighlight('.step0');

    function doStep(event, inc) {
      var currentStep = window.parseInt(slide.attr('data-step')) || 0,
          nextStep    = currentStep + inc,
          selector    = '.step'+nextStep;

      if (originalPre.find(selector).length > 0) {
        event.preventDefault();
        pre.html(originalPre.html());
        doHighlight(selector);
        slide.attr('data-step', nextStep);
      }
    }

    function doHighlight(selector) {
      pre.find(selector).highlight('ruby').addClass('current');
    }
  });
}

$.fn.swapElements = function(aSelector, bSelector) {
  this.each(function(i, e) {
    var slide = $(e),
        a     = slide.find(aSelector),
        b     = slide.find(bSelector);

    a.parent().css('position', 'relative');

    var aPos  = a.position(),
        bPos  = b.position();

    a.css({position: 'absolute', top: aPos.top, left: aPos.left});
    b.css({position: 'absolute', top: bPos.top, left: bPos.left});

    slide.bind('showoff:next', function(event) {
      if (slide.hasClass('swapped')) return;

      event.preventDefault();
      a.animate({top: bPos.top, left: bPos.left});
      b.animate({top: aPos.top, left: aPos.left});
      slide.addClass('swapped');
    });

    slide.bind('showoff:prev', function(event) {
      if (!slide.hasClass('swapped')) return;

      event.preventDefault();
      a.animate({top: aPos.top, left: aPos.left});
      b.animate({top: bPos.top, left: bPos.left});
      slide.removeClass('swapped');
    });
  });
}
