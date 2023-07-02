use crate::{browser, engine, sheet};

mod state;
pub struct RedHatBoy {
    state: state::RedHatBoyStateMachine,
    sheet: sheet::Sheet,
    image: web_sys::HtmlImageElement,
}

impl RedHatBoy {
    pub async fn new() -> anyhow::Result<Self> {
        let json = browser::fetch_json("rhb.json").await?;
        use gloo_utils::format::JsValueSerdeExt;

        Ok(RedHatBoy {
            state: state::RedHatBoyStateMachine::default(),
            sheet: json.into_serde::<sheet::Sheet>()?,
            image: engine::load_image("rhb.png").await?,
        })
    }

    pub fn draw(&self, renderer: &engine::Renderer) {
        let sprite = self.current_sprite().expect("Cell not found");
        renderer.draw_image(
            &self.image,
            &engine::Rect {
                x: sprite.frame.x.into(),
                y: sprite.frame.y.into(),
                width: sprite.frame.w.into(),
                height: sprite.frame.h.into(),
            },
            &self.destination_box(),
        );
        renderer.draw_rect(&self.bounding_box());
    }
    fn frame_name(&self) -> String {
        format!(
            "{} ({}).png",
            self.state.frame_name(),
            (self.state.context().frame / 3) + 1
        )
    }
    fn current_sprite(&self) -> Option<&sheet::Cell> {
        self.sheet.frames.get(&self.frame_name())
    }
    pub fn destination_box(&self) -> engine::Rect {
        let sprite = self.current_sprite().expect("Cell not found");
        let x = sprite.sprite_source_size.x as i16;
        let y = sprite.sprite_source_size.y as i16;
        engine::Rect {
            x: (self.state.context().position.x + x).into(),
            y: (self.state.context().position.y + y).into(),
            width: sprite.frame.w.into(),
            height: sprite.frame.h.into(),
        }
    }
    pub fn bounding_box(&self) -> engine::Rect {
        const X_OFFSET: f32 = 18.0;
        const Y_OFFSET: f32 = 14.0;
        const WIDTH_OFFSET: f32 = 28.0;
        let mut bounding_box = self.destination_box();
        bounding_box.x += X_OFFSET;
        bounding_box.width -= WIDTH_OFFSET;
        bounding_box.y += Y_OFFSET;
        bounding_box.height -= Y_OFFSET;
        bounding_box
    }
    pub fn pos_y(&self) -> i16 {
        self.state.context().position.y
    }
    pub fn velocity_y(&self) -> i16 {
        self.state.context().velocity.y
    }
    pub fn update(&mut self) {
        self.transition(state::Event::Update);
    }
    pub fn run_right(&mut self) {
        self.transition(state::Event::Run);
    }
    pub fn slide(&mut self) {
        self.transition(state::Event::Slide);
    }
    pub fn jump(&mut self) {
        self.transition(state::Event::Jump);
    }

    pub fn land_on(&mut self, position: f32) {
        self.transition(state::Event::Land(position));
    }

    pub fn knock_out(&mut self) {
        self.transition(state::Event::KnockOut);
    }
    fn transition(&mut self, event: state::Event) {
        self.state = self.state.transition(event);
    }
}
