use gloo_utils::format::JsValueSerdeExt;

use crate::{browser, engine, rhb};

pub const HEIGHT: i16 = 600;
const FIRST_PLATFORM: i16 = 370;
const LOW_PLATFORM: i16 = 420;
pub struct Walk {
    boy: rhb::RedHatBoy,
    backgrounds: [engine::Image; 2],
    obstacles: Vec<Box<dyn Obstacle>>,
}
impl Walk {
    fn velocity(&self) -> i16 {
        -self.boy.walking_speed()
    }
}
struct Platform {
    sheet: engine::SpriteSheet,
    position: engine::Point,
}
impl Platform {
    fn new(sheet: engine::SpriteSheet, position: engine::Point) -> Self {
        Platform { sheet, position }
    }

    pub fn destination_box(&self) -> engine::Rect {
        let platform = self.sheet.cell("13.png").expect("13.png does not exist");
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
impl Obstacle for Platform {
    fn move_horizontally(&mut self, x: i16) {
        self.position.x += x;
    }

    fn check_intersection(&self, boy: &mut rhb::RedHatBoy) {
        if let Some(box_to_land_on) = self
            .bounding_boxes()
            .iter()
            .find(|&bounding_box| boy.bounding_box().intersects(bounding_box))
        {
            if boy.velocity_y() > 0 && boy.pos_y() < self.position.y {
                boy.land_on(box_to_land_on.y());
            } else {
                boy.knock_out();
            }
        }
    }

    fn draw(&self, renderer: &engine::Renderer) {
        let platform = self.sheet.cell("13.png").expect("13.png does not exist");
        let rect = engine::Rect::new_from_xy(
            platform.frame.x,
            platform.frame.y,
            platform.frame.w * 3,
            platform.frame.h,
        );
        self.sheet.draw(renderer, &rect, &self.destination_box());
        for ele in self.bounding_boxes() {
            renderer.draw_rect(&ele);
        }
    }

    fn right(&self) -> i16 {
        self.bounding_boxes()
            .last()
            .unwrap_or(&engine::Rect::default())
            .right()
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
                    engine::SpriteSheet::new(
                        platform_sheet.into_serde::<engine::Sheet>()?,
                        engine::load_image("tiles.png").await?,
                    ),
                    engine::Point { x: 200, y: 400 },
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
                    obstacles: vec![
                        Box::new(Barrier::new(engine::Image::new(
                            stone,
                            engine::Point { x: 150, y: 546 },
                        ))),
                        Box::new(platform),
                    ],
                };
                *self = WalkTheDog::Loaded(walk);
                Ok(())
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

            walk.boy.update();
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
            walk.obstacles.retain(|obstacle| obstacle.right() > 0);
            walk.obstacles.iter_mut().for_each(|obstacle| {
                obstacle.move_horizontally(velocity);
                obstacle.check_intersection(&mut walk.boy);
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
            walk.obstacles.iter().for_each(|obstacle| {
                obstacle.draw(renderer);
            });
        }
    }
}
pub trait Obstacle {
    fn check_intersection(&self, boy: &mut rhb::RedHatBoy);
    fn draw(&self, renderer: &engine::Renderer);
    fn move_horizontally(&mut self, x: i16);
    fn right(&self) -> i16;
}
pub struct Barrier {
    image: engine::Image,
}
impl Barrier {
    pub fn new(image: engine::Image) -> Self {
        Barrier { image }
    }
}
impl Obstacle for Barrier {
    fn check_intersection(&self, boy: &mut rhb::RedHatBoy) {
        if boy.bounding_box().intersects(self.image.bounding_box()) {
            boy.knock_out()
        }
    }

    fn draw(&self, renderer: &engine::Renderer) {
        self.image.draw(renderer);
    }

    fn move_horizontally(&mut self, x: i16) {
        self.image.move_horizontally(x);
    }

    fn right(&self) -> i16 {
        self.image.right()
    }
}
