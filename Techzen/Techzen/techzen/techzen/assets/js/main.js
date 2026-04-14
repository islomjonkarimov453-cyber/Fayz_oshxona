(function (window, document, $, undefined) {
    'use strict';

    var rsthemeJs = {

        m: function (e) {
            rsthemeJs.d();
            rsthemeJs.methods();
        },

        d: function (e) {
            this._window = $(window),
                this._document = $(document),
                this._body = $('body'),
                this._html = $('html')
        },

        methods: function (e) {
            rsthemeJs.customjsActive();
            rsthemeJs.OwlCarousel();
        },

        customjsActive: function () {
            var $ = jQuery;

            //===== Menu Sticky

            var t = $(".menu-sticky"),
                a = $(window);

            a.on("scroll", function () {
                var o = a.scrollTop();
                o < 200 ? t.removeClass("sticky") : t.addClass("sticky");
                $("section").each(function () {
                    o >= $(this).offset().top - $("#rs-header").outerHeight() && $(this).addClass("loaded");
                });
            });


            //===== Offfcanvus Menu 

            $(".rs-sidebar-demo .collaps-btn, .panel-btn-part .collaps-btn").click(function () {
                $(this).parents("html").toggleClass("demo-is-open");
            });

            $(".canvasmenu-trigger, .menu-canvas-layer, .menu-canvas-close").click(function () {
                $(this).parents("html").toggleClass("menu-is-open");
            });

            $(".offcanvas-menu .offcanvas-menu-inner ul.nav-menu .has-clid > a").click(function (t) {
                t.preventDefault();
                $(this).parent(".has-clid").toggleClass("highlight");
            });


            //===== search popup

            var searchParent = $('.search_icons');
            if (searchParent.length) {
                $(".search_icons").on("click", function () {
                    $(this).toggleClass("open_add_class");
                });
            }


            //===== banner animation slick slider

            function mainSlider() {
                var BasicSlider = $('.rs-banner-slider');
                BasicSlider.on('init', function (e, slick) {
                    var $firstAnimatingElements = $('.items:first-child').find('[data-animation]');
                    doAnimations($firstAnimatingElements);
                });
                BasicSlider.on('beforeChange', function (e, slick, currentSlide, nextSlide) {
                    var $animatingElements = $('.items[data-slick-index="' + nextSlide + '"]').find('[data-animation]');
                    doAnimations($animatingElements);
                });
                BasicSlider.slick({
                    autoplay: true,
                    autoplaySpeed: 4000,
                    dots: false,
                    fade: true,
                    arrows: false,
                    focusOnSelect: false,
                    responsive: [
                        {
                            breakpoint: 1330,
                            settings: {
                                arrows: false
                            }
                        }
                    ]
                });

                function doAnimations(elements) {
                    var animationEndEvents = 'webkitAnimationEnd mozAnimationEnd MSAnimationEnd oanimationend animationend';
                    elements.each(function () {
                        var $this = $(this);
                        var $animationDelay = $this.data('delay');
                        var $animationType = 'animated ' + $this.data('animation');
                        $this.css({
                            'animation-delay': $animationDelay,
                            '-webkit-animation-delay': $animationDelay
                        });
                        $this.addClass($animationType).one(animationEndEvents, function () {
                            $this.removeClass($animationType);
                        });
                    });
                }
            }
            mainSlider();


            //===== Videos popup jQuery 

            var popupvideos = $('.rs-popup-videos');
            if (popupvideos.length) {
                $('.rs-popup-videos').magnificPopup({
                    disableOn: 10,
                    type: 'iframe',
                    mainClass: 'mfp-fade',
                    removalDelay: 160,
                    preloader: false,
                    fixedContentPos: false
                });
            }


            //===== flickity main

            $('.carousel-main').flickity();


            //===== flickity navigation

            $('.carousel-nav').flickity({
                asNavFor: '.carousel-main',
                contain: true,
                pageDots: false
            });


            //===== Back To Top

            $(window).on("scroll", function () {
                var scrollTop = $(window).scrollTop();
                var documentHeight = $(document).height();
                var windowHeight = $(window).height();
                $(".progress-circle").css("stroke-dashoffset", 113.1 - 113.1 * (scrollTop / (documentHeight - windowHeight)));
                if (scrollTop > 150) {
                    $("#scrollUp").fadeIn();
                } else {
                    $("#scrollUp").fadeOut();
                }
            });            
            $("#scrollUp").on("click", function () {
                $("html,body").animate({ scrollTop: 0 }, 500);
            });


            //===== skeletabs js active

            var skeletabs = $('#rs-tabs');
            if (skeletabs.length) {
                $('#rs-tabs').skeletabs({
                    panelHeight: 'adapt',
                });
            }

            //===== Progress Bar
            
            if ($(".rs-count-bar").length) {
                $(".rs-count-bar").appear(
                function () {
                    var el = $(this);
                    var percent = el.data("percent");
                    $(el).css("width", percent).addClass("counted");
                }, {
                    accY: -50
                }
                );
            }


            //===== accordion active

            $(".accordion_tab").click(function(){
                $(".accordion_tab").each(function(){
                  $(this).parent().removeClass("active");
                  $(this).removeClass("active");
                });
                $(this).parent().addClass("active");
                $(this).addClass("active");
            });


            //===== marquee active

            $(".marquee_text").data("marquee-loaded") ||
            ($(".marquee_text").each(function () {
                var t = $(this).data("direction"),
                    a = true === $(this).data("hover-pause"),
                    o = false,
                    n = $(this).marquee({ direction: t, duration: $(this).data("duration"), gap: $(this).data("gap"), delayBeforeStart: 0, duplicated: true, startVisible: true, pauseOnHover: a });
                $(this).on("mousedown", function () {
                    o = true;
                    n.marquee("pause");
                    $(this).data("mouse-down", true);
                });
                $(this).on("mouseup", function () {
                    o = false;
                    if (!$(this).data("mouse-dragged")) {
                        n.marquee("resume");
                    }
                    $(this).data("mouse-down", false);
                    $(this).data("mouse-dragged", false);
                });
                $(this).on("mousemove", function () {
                    if (o) {
                        $(this).data("mouse-dragged", true);
                    }
                });
            }),
            $(".marquee_text").data("marquee-loaded", true));


            //===== Odometer js

            $('.odometer').appear(function(e) {
                var odo = $(".odometer");
                odo.each(function() {
                    var countNumber = $(this).attr("data-count");
                    $(this).html(countNumber);
                });
            });


            //===== slider range js

            $('#price-range-submit').hide();
            $("#min_price,#max_price").on('change', function () {
              $('#price-range-submit').show();
              var min_price_range = parseInt($("#min_price").val());
              var max_price_range = parseInt($("#max_price").val());
              if (min_price_range > max_price_range) {
                $('#max_price').val(min_price_range);
              }
              $("#slider-range").slider({
                values: [min_price_range, max_price_range]
              });
            });
            $("#min_price,#max_price").on("paste keyup", function () {            
              $('#price-range-submit').show();
              var min_price_range = parseInt($("#min_price").val());
              var max_price_range = parseInt($("#max_price").val());
              if(min_price_range == max_price_range){
                max_price_range = min_price_range + 100;
                $("#min_price").val(min_price_range);		
                $("#max_price").val(max_price_range);
              }
              $("#slider-range").slider({
                values: [min_price_range, max_price_range]
              });
            });
            $(function () {
              $("#slider-range").slider({
                range: true,
                orientation: "horizontal",
                min: 0,
                max: 10000,
                values: [0, 10000],
                step: 100,
                slide: function (event, ui) {
                  if (ui.values[0] == ui.values[1]) {
                    return false;
                  }
                  $("#min_price").val(ui.values[0]);
                  $("#max_price").val(ui.values[1]);
                }
              });
              $("#min_price").val($("#slider-range").slider("values", 0));
              $("#max_price").val($("#slider-range").slider("values", 1));
            });
            $("#slider-range,#price-range-submit").click(function () {
              var min_price = $('#min_price').val();
              var max_price = $('#max_price').val();
              $("#searchResults").text("Here List of products will be shown which are cost between " + min_price  +" "+ "and" + " "+ max_price + ".");
            });


            //=====  wow Animation

            new WOW().init();


            //===== preloader

            $(window).on( 'load', function() {
                $("#pre-load").delay(300).fadeOut(200);
                $(".pre-loader").on('click', function() {
                    $(".pre-loader").fadeOut(200);
                })
            })

            //===== PageScroll2id active js
            
            $(window).on("load", function () {

                $(".rs-header .nav-menu a,a[href='#top'],a[rel='m_PageScroll2id']").mPageScroll2id({
                    highlightSelector: ".rs-header .nav-menu a"
                });
                
                $("a[rel='next']").click(function (e) {
                    e.preventDefault();
                    var to = $(this).parent().parent("section").next().attr("id");
                    $.mPageScroll2id("scrollTo", to);
                });
                
            });




        },

        OwlCarousel: function () {
            // OwlCarousel
            $('.rs-carousel').each(function () {
                var owlCarousel = $(this),
                    loop = owlCarousel.data('loop'),
                    items = owlCarousel.data('items'),
                    dotsEach = owlCarousel.data('doteach'),
                    margin = owlCarousel.data('margin'),
                    stagePadding = owlCarousel.data('stage-padding'),
                    autoplay = owlCarousel.data('autoplay'),
                    autoplayTimeout = owlCarousel.data('autoplay-timeout'),
                    smartSpeed = owlCarousel.data('smart-speed'),
                    dots = owlCarousel.data('dots'),
                    nav = owlCarousel.data('nav'),
                    navSpeed = owlCarousel.data('nav-speed'),
                    xsDevice = owlCarousel.data('mobile-device'),
                    xsDeviceNav = owlCarousel.data('mobile-device-nav'),
                    xsDeviceDots = owlCarousel.data('mobile-device-dots'),
                    smDevice = owlCarousel.data('ipad-device'),
                    smDeviceNav = owlCarousel.data('ipad-device-nav'),
                    smDeviceDots = owlCarousel.data('ipad-device-dots'),
                    smDevice2 = owlCarousel.data('ipad-device2'),
                    smDeviceNav2 = owlCarousel.data('ipad-device-nav2'),
                    smDeviceDots2 = owlCarousel.data('ipad-device-dots2'),
                    mdDevice = owlCarousel.data('md-device'),
                    lgDevice = owlCarousel.data('lg-device'),
                    centerMode = owlCarousel.data('center-mode'),
                    HoverPause = owlCarousel.data('hoverpause'),
                    mdDeviceNav = owlCarousel.data('md-device-nav'),
                    mdDeviceDots = owlCarousel.data('md-device-dots');
                    owlCarousel.owlCarousel({
                    loop: (loop ? true : false),
                    dotsEach: (dotsEach ? true : false),
                    items: (items ? items : 4),
                    lazyLoad: true,
                    center: (centerMode ? true : false),
                    autoplayHoverPause: (HoverPause ? true : false),
                    margin: (margin ? margin : 0),
                    //stagePadding: (stagePadding ? stagePadding : 0),
                    autoplay: (autoplay ? true : false),
                    autoplayTimeout: (autoplayTimeout ? autoplayTimeout : 1000),
                    smartSpeed: (smartSpeed ? smartSpeed : 250),
                    dots: (dots ? true : false),
                    nav: (nav ? true : false),
                    navText: ["<i class='ri-arrow-left-fill'></i> <span>Prev</span>", "<span>Next</span> <i class='ri-arrow-right-fill'></i>"],
                    navSpeed: (navSpeed ? true : false),
                    responsiveClass: true,
                    responsive: {
                        0: {
                            items: (xsDevice ? xsDevice : 1),
                            nav: (xsDeviceNav ? true : false),
                            dots: (xsDeviceDots ? true : false),
                            center: false,
                        },
                        576: {
                            items: (smDevice2 ? smDevice2 : 2),
                            nav: (smDeviceNav2 ? true : false),
                            dots: (smDeviceDots2 ? true : false),
                            center: false,
                        },
                        768: {
                            items: (smDevice ? smDevice : 3),
                            nav: (smDeviceNav ? true : false),
                            dots: (smDeviceDots ? true : false),
                            center: false,
                        },
                        992: {
                            items: (mdDevice ? mdDevice : 4),
                            nav: (mdDeviceNav ? true : false),
                            dots: (mdDeviceDots ? true : false),
                        },
                        1200: {
                            items: (lgDevice ? lgDevice : 4),
                        }
                    },
                });
            });
        },
    }
    rsthemeJs.m();

})(window, document, jQuery)

