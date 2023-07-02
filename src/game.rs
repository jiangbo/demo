use gloo_utils::format::JsValueSerdeExt;
use web_sys::HtmlImageElement;

use crate::{browser, engine, rhb, sheet};

pub const HEIGHT: i16 = 600;
const FIRST_PLATFORM: i16 = 370;
const LOW_PLATFORM: i16 = 420;
pub struct Walk {
    boy: rhb::RedHatBoy,
    background: engine::Image,
    stone: engine::Image,
    platform: Platform,
}
struct Platform {
    sheet: sheet::Sheet,
    image: HtmlImageElement,
    position: engine::Point,
}
impl Platform {
    fn new(sheet: sheet::Sheet, image: HtmlImageElement, position: engine::Point) -> Self {
        Platform {
            sheet,
            image,
            position,
        }
    }

    fn draw(&self, renderer: &engine::Renderer) {
        let platform = self
            .sheet
            .frames
            .get("13.png")
            .expect("13.png does not exist");
        renderer.draw_image(
            &self.image,
            &engine::Rect {
                x: platform.frame.x.into(),
                y: platform.frame.y.into(),
                width: (platform.frame.w * 3).into(),
                height: platform.frame.h.into(),
            },
            &self.destination_box(),
        );
        for ele in self.bounding_boxes() {
            renderer.draw_rect(&ele);
        }
    }
    pub fn destination_box(&self) -> engine::Rect {
        let platform = self
            .sheet
            .frames
            .get("13.png")
            .expect("13.png does not exist");
        engine::Rect {
            x: self.position.x.into(),
            y: self.position.y.into(),
            width: (platform.frame.w * 3).into(),
            height: platform.frame.h.into(),
        }
    }
    fn bounding_boxes(&self) -> Vec<engine::Rect> {
        const X_OFFSET: f32 = 60.0;
        const END_HEIGHT: f32 = 54.0;

        let destination_box = self.destination_box();
        let bounding_box_one = engine::Rect {
            x: destination_box.x,
            y: destination_box.y,
            width: X_OFFSET,
            height: END_HEIGHT,
        };
        let bounding_box_two = engine::Rect {
            x: destination_box.x + X_OFFSET,
            y: destination_box.y,
            width: destination_box.width - (X_OFFSET * 2.0),
            height: destination_box.height,
        };
        let bounding_box_three = engine::Rect {
            x: destination_box.x + destination_box.width - X_OFFSET,
            y: destination_box.y,
            width: X_OFFSET,
            height: END_HEIGHT,
        };
        vec![bounding_box_one, bounding_box_two, bounding_box_three]
    }
}
pub enum WalkTheDog {
    Loading,
    Loaded(Walk),
}
impl WalkTheDog {
    pub fn new() -> Self {
        WalkTheDog::Loading
    }
}
#[async_trait::async_trait(?Send)]
impl engine::Game for WalkTheDog {
    async fn initialize(&mut self) -> anyhow::Result<()> {
        match self {
            WalkTheDog::Loading => {
                let background = engine::load_image("BG.png").await?;
                let stone = engine::load_image("Stone.png").await?;
                let platform_sheet = browser::fetch_json("tiles.json").await?;
                let platform = Platform::new(
                    platform_sheet.into_serde::<sheet::Sheet>()?,
                    engine::load_image("tiles.png").await?,
                    engine::Point {
                        x: FIRST_PLATFORM,
                        y: LOW_PLATFORM,
                    },
                );
                let walk = Walk {
                    boy: rhb::RedHatBoy::new().await?,
                    background: engine::Image::origin(background),
                    stone: engine::Image::new(stone, engine::Point { x: 150, y: 546 }),
                    platform,
                };
                Ok(*self = WalkTheDog::Loaded(walk))
            }
            WalkTheDog::Loaded(_) => Err(anyhow::anyhow!("Error: Game is initialized!")),
        }
    }

    fn update(&mut self, keystate: &engine::KeyState) {
        if let WalkTheDog::Loaded(walk) = self {
            if keystate.is_pressed("ArrowRight") {
                walk.boy.run_right();
            }
            if keystate.is_pressed("ArrowDown") {
                walk.boy.slide();
            }
            if keystate.is_pressed("Space") {
                walk.boy.jump();
            }
            for bounding_box in &walk.platform.bounding_boxes() {
                if walk.boy.bounding_box().intersects(bounding_box) {
                    if walk.boy.velocity_y() > 0 && walk.boy.pos_y() < walk.platform.position.y {
                        walk.boy.land_on(bounding_box.y);
                    } else {
                        walk.boy.knock_out();
                    }
                }
            }
            if walk
                .boy
                .bounding_box()
                .intersects(walk.stone.bounding_box())
            {
                walk.boy.knock_out();
            }
            walk.boy.update();
        }
    }
    fn draw(&self, renderer: &engine::Renderer) {
        renderer.clear(&engine::Rect {
            x: 0.0,
            y: 0.0,
            width: 600.0,
            height: HEIGHT as f32,
        });
        if let WalkTheDog::Loaded(walk) = self {
            walk.background.draw(renderer);
            walk.boy.draw(renderer);
            walk.stone.draw(renderer);
            walk.platform.draw(renderer);
        }
    }
}
