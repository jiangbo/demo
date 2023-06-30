use std::collections::HashMap;

use crate::{browser, engine};
use async_trait::async_trait;
use gloo_utils::format::JsValueSerdeExt;

#[derive(Debug, serde::Deserialize)]
struct SheetRect {
    x: i16,
    y: i16,
    w: i16,
    h: i16,
}
#[derive(Debug, serde::Deserialize)]
struct Cell {
    frame: SheetRect,
}
#[derive(Debug, serde::Deserialize)]
pub struct Sheet {
    frames: HashMap<String, Cell>,
}

pub struct WalkTheDog {
    image: Option<web_sys::HtmlImageElement>,
    pub sheet: Option<Sheet>,
    frame: u8,
}

impl WalkTheDog {
    pub fn new() -> Self {
        WalkTheDog {
            image: None,
            sheet: None,
            frame: 0,
        }
    }
}
#[async_trait(?Send)]
impl engine::Game for WalkTheDog {
    async fn initialize(&mut self) -> anyhow::Result<()> {
        let sheet: Sheet = browser::fetch_json("rhb.json").await?.into_serde()?;
        let image = engine::load_image("rhb.png").await?;
        // Ok(Box::new(WalkTheDog {
        //     image: Some(image),
        //     sheet: Some(sheet),
        //     frame: self.frame,
        // }))
        self.image = Some(image);
        self.sheet = Some(sheet);

        Ok(())
    }

    fn update(&mut self) {
        if self.frame < 23 {
            self.frame += 1;
        } else {
            self.frame = 0;
        }
    }

    fn draw(&self, renderer: &engine::Renderer) {
        let current_sprite = (self.frame / 3) + 1;
        let frame_name = format!("Run ({}).png", current_sprite);
        let sprite = self
            .sheet
            .as_ref()
            .and_then(|sheet| sheet.frames.get(&frame_name))
            .expect("Cell not found");
        renderer.clear(&engine::Rect {
            x: 0.0,
            y: 0.0,
            width: 600.0,
            height: 600.0,
        });
        if let Some(image) = self.image.as_ref() {
            renderer.draw_image(
                image,
                &engine::Rect {
                    x: sprite.frame.x.into(),
                    y: sprite.frame.y.into(),
                    width: sprite.frame.w.into(),
                    height: sprite.frame.h.into(),
                },
                &engine::Rect {
                    x: 300.0,
                    y: 300.0,
                    width: sprite.frame.w.into(),
                    height: sprite.frame.h.into(),
                },
            );
        }
    }
}
