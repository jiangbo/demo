use gloo_utils::format::JsValueSerdeExt;
use web_sys::HtmlImageElement;

use crate::{browser, engine, rhb};

pub const HEIGHT: i16 = 600;
const FIRST_PLATFORM: i16 = 370;
const LOW_PLATFORM: i16 = 420;
pub struct Walk {
    boy: rhb::RedHatBoy,
    backgrounds: [engine::Image; 2],
    stone: engine::Image,
    platform: Platform,
}
impl Walk {
    fn velocity(&self) -> i16 {
        -self.boy.walking_speed()
    }
}
struct Platform {
    sheet: engine::Sheet,
    image: HtmlImageElement,
    position: engine::Point,
}
impl Platform {
    fn new(sheet: engine::Sheet, image: HtmlImageElement, position: engine::Point) -> Self {
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
            &engine::Rect::new_from_xy(
                platform.frame.x,
                platform.frame.y,
                platform.frame.w * 3,
                platform.frame.h,
            ),
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
        engine::Rect::new_from_xy(
            self.position.x,
            self.position.y,
            platform.frame.w * 3,
            platform.frame.h,
        )
    }
    fn bounding_boxes(&self) -> Vec<engine::Rect> {
        const X_OFFSET: i16 = 60;
        const END_HEIGHT: i16 = 54;

        let destination_box = self.destination_box();
        let bounding_box_one = engine::Rect::new_from_xy(
            destination_box.x(),
            destination_box.y(),
            X_OFFSET,
            END_HEIGHT,
        );
        let bounding_box_two = engine::Rect::new_from_xy(
            destination_box.x() + X_OFFSET,
            destination_box.y(),
            destination_box.width - (X_OFFSET * 2),
            destination_box.height,
        );
        let bounding_box_three = engine::Rect::new_from_xy(
            destination_box.x() + destination_box.width - X_OFFSET,
            destination_box.y(),
            X_OFFSET,
            END_HEIGHT,
        );
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
                let stone = engine::load_image("Stone.png").await?;
                let platform_sheet = browser::fetch_json("tiles.json").await?;
                let platform = Platform::new(
                    platform_sheet.into_serde::<engine::Sheet>()?,
                    engine::load_image("tiles.png").await?,
                    engine::Point {
                        x: FIRST_PLATFORM,
                        y: LOW_PLATFORM,
                    },
                );
                let background = engine::load_image("BG.png").await?;
                let point = engine::Point {
                    x: background.width() as i16,
                    y: 0,
                };
                let backgrounds = [
                    engine::Image::new(background.clone(), engine::Point::default()),
                    engine::Image::new(background, point),
                ];
                let walk = Walk {
                    boy: rhb::RedHatBoy::new().await?,
                    backgrounds,
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
                        walk.boy.land_on(bounding_box.y());
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
            walk.platform.position.x += walk.velocity();
            walk.stone.move_horizontally(walk.velocity());
            let velocity = walk.velocity();
            let [first_background, second_background] = &mut walk.backgrounds;
            first_background.move_horizontally(velocity);
            second_background.move_horizontally(velocity);
            if first_background.right() < 0 {
                first_background.set_x(second_background.right());
            }
            if second_background.right() < 0 {
                second_background.set_x(first_background.right());
            }
            walk.backgrounds.iter_mut().for_each(|background| {
                background.move_horizontally(velocity);
            });
        }
    }
    fn draw(&self, renderer: &engine::Renderer) {
        renderer.clear(&engine::Rect {
            position: engine::Point::default(),
            width: 600,
            height: HEIGHT,
        });
        if let WalkTheDog::Loaded(walk) = self {
            walk.backgrounds.iter().for_each(|background| {
                background.draw(renderer);
            });
            walk.boy.draw(renderer);
            walk.stone.draw(renderer);
            walk.platform.draw(renderer);
        }
    }
}
