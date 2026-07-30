///|
/// Print a compact HTML report for smoke testing and demos.
fn main {
  let detections = @visual.Layer::new(id="detections")
    .add(
      @visual.BBox(
        rect=@visual.Rect::new(x=24.0, y=20.0, width=96.0, height=72.0),
        label=Some(@visual.Label::new(text="widget", score=0.88)),
        color=Some(@visual.Color::rgb(r=39, g=125, b=255)),
      ),
    )
    .add(
      @visual.Keypoints(
        points=[
          @visual.Keypoint::new(
            point=@visual.Point::new(x=44.0, y=48.0),
            name="corner-a",
          ),
          @visual.Keypoint::new(
            point=@visual.Point::new(x=104.0, y=76.0),
            name="corner-b",
          ),
        ],
        color=Some(@visual.Color::rgb(r=16, g=185, b=129)),
      ),
    )
  let heat = @visual.Layer::new(id="activation").add(
    @visual.Heatmap(
      cells=[
        @visual.HeatCell::new(
          rect=@visual.Rect::new(x=0.0, y=0.0, width=40.0, height=40.0),
          value=0.2,
        ),
        @visual.HeatCell::new(
          rect=@visual.Rect::new(x=40.0, y=0.0, width=40.0, height=40.0),
          value=0.8,
        ),
      ],
      low=None,
      high=None,
    ),
  )
  let doc = @visual.DebugDocument::new(
      title="MoonBit visual debug sample",
      image=@visual.ImageSpec::new(width=160, height=110),
    )
    .add_layer(detections)
    .add_layer(heat)
  println(doc.to_html_report())
}
