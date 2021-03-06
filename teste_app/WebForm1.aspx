﻿<%@ Page Title="" Language="C#" MasterPageFile="~/masterpage.Master" AutoEventWireup="true" CodeBehind="WebForm1.aspx.cs" Inherits="teste_app.WebForm1" %>
<asp:Content ID="Content1" ContentPlaceHolderID="head" runat="server">

    <title>Teste Odissey</title>
   <link rel="stylesheet" href="http://cartodb-libs.global.ssl.fastly.net/cartodb.js/v3/themes/css/cartodb.css">
  <link rel="stylesheet" href="http://cartodb.github.io/odyssey.js/sandbox/css/slides.css">
  <script src="http://cartodb.github.io/odyssey.js/vendor/modernizr-2.6.2.min.js"></script>


</asp:Content>
<asp:Content ID="Content2" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">

   <div id="map" style="width: 100%; height: 100%;"></div>

  <div id="slides_container" style="display:block;">
    <div id="dots"></div>

    <div id="slides"></div>

    <ul id="navButtons">
      <li><a class="prev"></a></li>
      <li><a class="next"></a></li>
    </ul>
  </div>

  <div id="credits">
    <span class="title" id="title">Title</span>
    <span class="author"><strong id="author">By Name using</strong> <a href="http://cartodb.github.io/odyssey.js/">Odyssey.js</a><span>
  </span></span></div>

  <script src="http://cartodb-libs.global.ssl.fastly.net/cartodb.js/v3/cartodb.js"></script>
  <script src="http://cartodb.github.io/odyssey.js/dist/odyssey.js" charset="UTF-8"></script>

  <script>
      var resizePID;

      function clearResize() {
          clearTimeout(resizePID);
          resizePID = setTimeout(function () { adjustSlides(); }, 100);
      }

      if (!window.addEventListener) {
          window.attachEvent("resize", function load(event) {
              clearResize();
          });
      } else {
          window.addEventListener("resize", function load(event) {
              clearResize();
          });
      }

      function adjustSlides() {
          var container = document.getElementById("slides_container"),
              slide = document.querySelectorAll('.selected_slide')[0];

          if (slide) {
              if (slide.offsetHeight + 169 + 40 + 80 >= window.innerHeight) {
                  container.style.bottom = "80px";

                  var h = container.offsetHeight;

                  slide.style.height = h - 169 + "px";
                  slide.classList.add("scrolled");
              } else {
                  container.style.bottom = "auto";
                  container.style.minHeight = "0";

                  slide.style.height = "auto";
                  slide.classList.remove("scrolled");
              }
          }
      }

      var resizeAction = O.Action(function () {
          function imageLoaded() {
              counter--;

              if (counter === 0) {
                  adjustSlides();
              }
          }
          var images = $('img');
          var counter = images.length;

          images.each(function () {
              if (this.complete) {
                  imageLoaded.call(this);
              } else {
                  $(this).one('load', imageLoaded);
              }
          });
      });

      function click(el) {
          var element = O.Core.getElement(el);
          var t = O.Trigger();

          // TODO: clean properly
          function click() {
              t.trigger();
          }

          if (element) element.onclick = click;

          return t;
      }

      O.Template({
          init: function () {
              var seq = O.Triggers.Sequential();

              var baseurl = this.baseurl = 'http://{s}.api.cartocdn.com/base-light/{z}/{x}/{y}.png';
              var map = this.map = L.map('map').setView([0, 0.0], 4);
              var basemap = this.basemap = L.tileLayer(baseurl, {
                  attribution: 'data OSM - map CartoDB'
              }).addTo(map);

              // enanle keys to move
              O.Keys().on('map').left().then(seq.prev, seq)
              O.Keys().on('map').right().then(seq.next, seq)

              click(document.querySelectorAll('.next')).then(seq.next, seq)
              click(document.querySelectorAll('.prev')).then(seq.prev, seq)

              var slides = O.Actions.Slides('slides');
              var story = O.Story()

              this.story = story;
              this.seq = seq;
              this.slides = slides;
              this.progress = O.UI.DotProgress('dots').count(0);
          },

          update: function (actions) {
              var self = this;

              if (!actions.length) return;

              this.story.clear();

              if (this.baseurl && (this.baseurl !== actions.global.baseurl)) {
                  this.baseurl = actions.global.baseurl || 'http://0.api.cartocdn.com/base-light/{z}/{x}/{y}.png';

                  this.basemap.setUrl(this.baseurl);
              }

              if (this.cartoDBLayer && ("http://" + self.cartoDBLayer.options.user_name + ".cartodb.com/api/v2/viz/" + self.cartoDBLayer.options.layer_definition.stat_tag + "/viz.json" !== actions.global.vizjson)) {
                  this.map.removeLayer(this.cartoDBLayer);

                  this.cartoDBLayer = null;
                  this.created = false;
              }

              if (actions.global.vizjson && !this.cartoDBLayer) {
                  if (!this.created) { // sendCode debounce < vis loader
                      cdb.vis.Loader.get(actions.global.vizjson, function (vizjson) {
                          self.map.fitBounds(vizjson.bounds);

                          cartodb.createLayer(self.map, vizjson)
                            .done(function (layer) {
                                self.cartoDBLayer = layer;

                                var sublayer = layer.getSubLayer(0),
                                    layer_name = layer.layers[0].options.layer_name,
                                    filter = actions.global.cartodb_filter ? " WHERE " + actions.global.cartodb_filter : "";

                                sublayer.setSQL("SELECT * FROM " + layer_name + filter)

                                self.map.addLayer(layer);

                                self._resetActions(actions);
                            }).on('error', function (err) {
                                console.log("some error occurred: " + err);
                            });
                      });

                      this.created = true;
                  }

                  return;
              }

              this._resetActions(actions);
          },

          _resetActions: function (actions) {
              // update footer title and author
              var title_ = actions.global.title === undefined ? '' : actions.global.title,
                  author_ = actions.global.author === undefined ? 'Using' : 'By ' + actions.global.author + ' using';

              document.getElementById('title').innerHTML = title_;
              document.getElementById('author').innerHTML = author_;
              document.title = title_ + " | " + author_ + ' Odyssey.js';

              var sl = actions;

              document.getElementById('slides').innerHTML = ''
              this.progress.count(sl.length);

              // create new story
              for (var i = 0; i < sl.length; ++i) {
                  var slide = sl[i];
                  var tmpl = "<div class='slide' style='diplay:none'>";

                  tmpl += slide.html();
                  tmpl += "</div>";
                  document.getElementById('slides').innerHTML += tmpl;

                  this.progress.step(i).then(this.seq.step(i), this.seq)

                  var actions = O.Parallel(
                    this.slides.activate(i),
                    slide(this),
                    this.progress.activate(i),
                    resizeAction
                  );

                  actions.on("finish.app", function () {
                      adjustSlides();
                  });

                  this.story.addState(
                    this.seq.step(i),
                    actions
                  )
              }

              this.story.go(this.seq.current());
          },

          changeSlide: function (n) {
              this.seq.current(n);
          }
      });
  </script>

  <script>
      (function (i, s, o, g, r, a, m) {
          i['GoogleAnalyticsObject'] = r; i[r] = i[r] || function () {
              (i[r].q = i[r].q || []).push(arguments)
          }, i[r].l = 1 * new Date(); a = s.createElement(o),
          m = s.getElementsByTagName(o)[0]; a.async = 1; a.src = g; m.parentNode.insertBefore(a, m)
      })(window, document, 'script', '//www.google-analytics.com/analytics.js', 'ga');

      ga('create', 'UA-20934186-21', 'cartodb.github.io');
      ga('send', 'pageview');
  </script>

  <script type="text/javascript" src="http://fast.fonts.net/jsapi/3af16084-ba56-49ca-b37d-0b49b59e1927.js"></script>

<script id="md_template" type="text/template">```
-baseurl: "https://2.maps.nlp.nokia.com/maptile/2.1/maptile/newest/normal.day/{z}/{x}/{y}/256/png8?lg=eng&token=A7tBPacePg9Mj_zghvKt9Q&app_id=KuYppsdXZznpffJsKT24"
-title: "Levantamento de invasões"
-author: "Arya Inventário Territorial"
-vizjson: "https://jovill.carto.com/api/v2/viz/88651f92-a50f-11e6-985a-0e05a8b3e3d7/viz.json"
```
#The Tattoo Map of San Francisco
```
- center: [-20.3363,-43.8982]
- zoom: 5
```
The History of American Tattooing and the City of San Francisco have an intimate relationship. This map explores that relationship. It is by no means authoritative, or comprehensive. Slides and information will be added, over time.

#Lyle Tuttle's First Tattoo Shop
```
- center: [37.7801, -122.4121]
- zoom: 16
```
![Lyle Tuttle](http://www.cdn1.inkedout4life.com/wp-content/uploads/2013/01/Lyle-Tuttle-artist-large.jpg)

Tuttle was born in Chariton, Iowa in 1931 but grew up in Ukiah, California. At the age of fourteen he purchased his first tattoo for $3.50. In 1949, he began tattooing professionally.[2] In 1954 he opened his own studio in San Francisco. This first shop was open for nearly 30 years. Tuttle tattooed Janis Joplin, Cher, Henry Fonda, Paul Stanley, Joan Baez, the Allman Brothers, and many other notable musicians, actors, and celebrities.

#Lyle Tuttle's Tattoo Museum and Studio
```
- center: [37.8024, -122.4135]
- zoom: 17
```
![Lyle Tuttle](http://www.lyletuttle.com/_Media/lyle-tuttle-2012_med.jpeg)

His first shop when working for Bert Grimm at 16 Cedar Way, Long Beach, CA. on "The Pike". After tattooing in Anchorage and Fairbanks, AK. and Oakland, CA., Lyle opened up shop in 1960 at #30 7th St., in between Mission St. and Market St., also referred to as South of Market, San Francisco, CA. As the story goes, the end of an era and the beginning of a new one. Lyle tattooed at #30 7th St., San Francisco, CA. for 29 and a half years, until the Loma Prieta Earthquake in 1989 caused the building to be "yellow tagged". The shop and the museum are both now open at 841 Columbus Avenue.

```</script></body></html>
     
</asp:Content>
