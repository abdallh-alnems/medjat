(function () {
  "use strict";

  var reduceMotion = window.matchMedia(
    "(prefers-reduced-motion: reduce)",
  ).matches;

  // Ink the register in once it is on screen: the marks land left-to-right,
  // the way a scribe fills a row.
  var register = document.querySelector(".register-frame");
  if (register) {
    if (reduceMotion) {
      register.classList.add("is-inked");
    } else {
      var inkObserver = new IntersectionObserver(
        function (entries) {
          entries.forEach(function (entry) {
            if (entry.isIntersecting) {
              entry.target.classList.add("is-inked");
              inkObserver.unobserve(entry.target);
            }
          });
        },
        { threshold: 0.35 },
      );
      inkObserver.observe(register);
    }
  }

  // Hovering one day highlights the same day in both eras.
  var cells = document.querySelectorAll("[data-col]");
  function setColumn(col, on) {
    document.querySelectorAll('[data-col="' + col + '"]').forEach(function (n) {
      n.classList.toggle("is-active", on);
    });
  }
  cells.forEach(function (cell) {
    var col = cell.getAttribute("data-col");
    cell.addEventListener("mouseenter", function () {
      setColumn(col, true);
    });
    cell.addEventListener("mouseleave", function () {
      setColumn(col, false);
    });
  });

  if (reduceMotion) {
    document.querySelectorAll(".reveal").forEach(function (n) {
      n.classList.add("is-visible");
    });
    return;
  }

  var revealObserver = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          revealObserver.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.12, rootMargin: "0px 0px -40px 0px" },
  );
  document.querySelectorAll(".reveal").forEach(function (n) {
    revealObserver.observe(n);
  });
})();
