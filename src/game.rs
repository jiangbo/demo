use std::collections::HashMap;

use crate::{browser, engine};
use anyhow::{anyhow, Result};
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
pub enum WalkTheDog {
    Loading,
    Loaded(RedHatBoy),
}
impl WalkTheDog {
    pub fn new() -> Self {
        WalkTheDog::Loading
    }
}
#[async_trait(?Send)]
impl engine::Game for WalkTheDog {
    async fn initialize(&mut self) -> Result<()> {
        match self {
            WalkTheDog::Loading => {
                let json = browser::fetch_json("rhb.json").await?;
                let rhb = RedHatBoy::new(
                    json.into_serde::<Sheet>()?,
                    engine::load_image("rhb.png").await?,
                );
                Ok(*self = WalkTheDog::Loaded(rhb))
            }
            WalkTheDog::Loaded(_) => Err(anyhow!("Error: Game is initialized!")),
        }
    }

    fn update(&mut self, keystate: &engine::KeyState) {
        if let WalkTheDog::Loaded(rhb) = self {
            if keystate.is_pressed("ArrowRight") {
                rhb.run_right();
            }
            if keystate.is_pressed("ArrowDown") {
                rhb.slide();
            }
            if keystate.is_pressed("Space") {
                rhb.jump();
            }
            rhb.update();
        }
    }
    fn draw(&self, renderer: &engine::Renderer) {
        renderer.clear(&engine::Rect {
            x: 0.0,
            y: 0.0,
            width: 600.0,
            height: HEIGHT as f32,
        });
        if let WalkTheDog::Loaded(rhb) = self {
            rhb.draw(renderer);
        }
    }
}
const HEIGHT: i16 = 600;
struct RedHatBoy {
    state: RedHatBoyStateMachine,
    sheet: Sheet,
    image: web_sys::HtmlImageElement,
}

impl RedHatBoy {
    fn new(sheet: Sheet, image: web_sys::HtmlImageElement) -> Self {
        RedHatBoy {
            state: RedHatBoyStateMachine::Idle(RedHatBoyState::new()),
            sheet,
            image,
        }
    }

    fn update(&mut self) {
        self.state = self.state.update();
    }

    fn draw(&self, renderer: &engine::Renderer) {
        let frame_name = format!(
            "{} ({}).png",
            self.state.frame_name(),
            (self.state.context().frame / 3) + 1
        );
        let sprite = self.sheet.frames.get(&frame_name).expect("Cell not found");
        renderer.draw_image(
            &self.image,
            &engine::Rect {
                x: sprite.frame.x.into(),
                y: sprite.frame.y.into(),
                width: sprite.frame.w.into(),
                height: sprite.frame.h.into(),
            },
            &engine::Rect {
                x: self.state.context().position.x.into(),
                y: self.state.context().position.y.into(),
                width: sprite.frame.w.into(),
                height: sprite.frame.h.into(),
            },
        );
    }
    fn run_right(&mut self) {
        self.state = self.state.transition(Event::Run);
    }
    fn slide(&mut self) {
        self.state = self.state.transition(Event::Slide);
    }
    fn jump(&mut self) {
        self.state = self.state.transition(Event::Jump);
    }
}
use red_hat_boy_states::*;
#[derive(Copy, Clone)]
enum RedHatBoyStateMachine {
    Idle(red_hat_boy_states::RedHatBoyState<Idle>),
    Running(red_hat_boy_states::RedHatBoyState<Running>),
    Sliding(RedHatBoyState<Sliding>),
    Jumping(RedHatBoyState<Jumping>),
}

pub enum Event {
    Run,
    Slide,
    Update,
    Jump,
}
impl From<RedHatBoyState<Running>> for RedHatBoyStateMachine {
    fn from(state: RedHatBoyState<Running>) -> Self {
        RedHatBoyStateMachine::Running(state)
    }
}
impl From<RedHatBoyState<Sliding>> for RedHatBoyStateMachine {
    fn from(state: RedHatBoyState<Sliding>) -> Self {
        RedHatBoyStateMachine::Sliding(state)
    }
}
impl From<RedHatBoyState<Idle>> for RedHatBoyStateMachine {
    fn from(state: RedHatBoyState<Idle>) -> Self {
        RedHatBoyStateMachine::Idle(state)
    }
}
impl From<SlidingEndState> for RedHatBoyStateMachine {
    fn from(end_state: SlidingEndState) -> Self {
        match end_state {
            SlidingEndState::Running(running_state) => running_state.into(),
            SlidingEndState::Sliding(sliding_state) => sliding_state.into(),
        }
    }
}
impl From<RedHatBoyState<Jumping>> for RedHatBoyStateMachine {
    fn from(state: RedHatBoyState<Jumping>) -> Self {
        RedHatBoyStateMachine::Jumping(state)
    }
}
impl From<JumpingEndState> for RedHatBoyStateMachine {
    fn from(state: JumpingEndState) -> Self {
        match state {
            JumpingEndState::Jumping(jumping) => jumping.into(),
            JumpingEndState::Landing(landing) => landing.into(),
        }
    }
}
impl RedHatBoyStateMachine {
    fn transition(self, event: Event) -> Self {
        match (self, event) {
            (RedHatBoyStateMachine::Idle(state), Event::Run) => state.run().into(),
            (RedHatBoyStateMachine::Idle(state), Event::Update) => state.update().into(),

            (RedHatBoyStateMachine::Running(state), Event::Slide) => state.slide().into(),
            (RedHatBoyStateMachine::Running(state), Event::Update) => state.update().into(),
            (RedHatBoyStateMachine::Running(state), Event::Jump) => state.jump().into(),

            (RedHatBoyStateMachine::Sliding(state), Event::Update) => state.update().into(),
            (RedHatBoyStateMachine::Jumping(state), Event::Update) => state.update().into(),
            _ => self,
        }
    }
    fn frame_name(&self) -> &str {
        match self {
            RedHatBoyStateMachine::Idle(state) => state.frame_name(),
            RedHatBoyStateMachine::Running(state) => state.frame_name(),
            RedHatBoyStateMachine::Sliding(state) => state.frame_name(),
            RedHatBoyStateMachine::Jumping(state) => state.frame_name(),
        }
    }
    fn context(&self) -> &RedHatBoyContext {
        match self {
            RedHatBoyStateMachine::Idle(state) => &state.context(),
            RedHatBoyStateMachine::Running(state) => &state.context(),
            RedHatBoyStateMachine::Sliding(state) => &state.context(),
            RedHatBoyStateMachine::Jumping(state) => state.context(),
        }
    }
    fn update(self) -> Self {
        self.transition(Event::Update)
    }
}
mod red_hat_boy_states {
    use crate::engine::Point;
    const FLOOR: i16 = 475;
    const IDLE_FRAME_NAME: &str = "Idle";
    const RUN_FRAME_NAME: &str = "Run";
    const RUNNING_SPEED: i16 = 3;
    const IDLE_FRAMES: u8 = 29;
    const RUNNING_FRAMES: u8 = 23;

    const SLIDING_FRAMES: u8 = 14;
    const SLIDING_FRAME_NAME: &str = "Slide";

    const JUMPING_FRAME_NAME: &str = "Jump";
    const JUMP_SPEED: i16 = -25;
    const JUMPING_FRAMES: u8 = 23;
    const GRAVITY: i16 = 1;
    #[derive(Copy, Clone)]
    pub struct RedHatBoyState<S> {
        context: RedHatBoyContext,
        _state: S,
    }
    impl<S> RedHatBoyState<S> {
        pub fn context(&self) -> &RedHatBoyContext {
            &self.context
        }
        fn update_context(&mut self, frames: u8) {
            self.context = self.context.update(frames);
        }
    }
    #[derive(Copy, Clone)]
    pub struct RedHatBoyContext {
        pub frame: u8,
        pub position: Point,
        pub velocity: Point,
    }
    impl RedHatBoyContext {
        fn update(mut self, frame_count: u8) -> Self {
            self.velocity.y += GRAVITY;

            if self.frame < frame_count {
                self.frame += 1;
            } else {
                self.frame = 0;
            }

            self.position.x += self.velocity.x;
            self.position.y += self.velocity.y;

            if self.position.y > FLOOR {
                self.position.y = FLOOR;
            }

            self
        }
        fn reset_frame(mut self) -> Self {
            self.frame = 0;
            self
        }
        fn run_right(mut self) -> Self {
            self.velocity.x += RUNNING_SPEED;
            self
        }
        fn set_vertical_velocity(mut self, y: i16) -> Self {
            self.velocity.y = y;
            self
        }
    }
    impl RedHatBoyState<Idle> {
        pub fn new() -> Self {
            RedHatBoyState {
                context: RedHatBoyContext {
                    frame: 0,
                    position: Point { x: 0, y: FLOOR },
                    velocity: Point { x: 0, y: 0 },
                },
                _state: Idle {},
            }
        }

        pub fn frame_name(&self) -> &str {
            IDLE_FRAME_NAME
        }

        pub fn run(self) -> RedHatBoyState<Running> {
            RedHatBoyState {
                context: self.context.reset_frame().run_right(),
                _state: Running {},
            }
        }
        pub fn update(mut self) -> Self {
            self.update_context(IDLE_FRAMES);
            self
        }
    }

    impl RedHatBoyState<Running> {
        pub fn frame_name(&self) -> &str {
            RUN_FRAME_NAME
        }
        pub fn update(mut self) -> Self {
            self.update_context(RUNNING_FRAMES);
            self
        }
        pub fn slide(self) -> RedHatBoyState<Sliding> {
            RedHatBoyState {
                context: self.context.reset_frame(),
                _state: Sliding {},
            }
        }
        pub fn jump(self) -> RedHatBoyState<Jumping> {
            RedHatBoyState {
                context: self.context.set_vertical_velocity(JUMP_SPEED).reset_frame(),
                _state: Jumping {},
            }
        }
    }
    impl RedHatBoyState<Sliding> {
        pub fn frame_name(&self) -> &str {
            SLIDING_FRAME_NAME
        }
        pub fn update(mut self) -> SlidingEndState {
            self.update_context(SLIDING_FRAMES);
            if self.context.frame >= SLIDING_FRAMES {
                SlidingEndState::Running(self.stand())
            } else {
                SlidingEndState::Sliding(self)
            }
        }
        pub fn stand(self) -> RedHatBoyState<Running> {
            RedHatBoyState {
                context: self.context.reset_frame(),
                _state: Running,
            }
        }
    }
    pub enum SlidingEndState {
        Running(RedHatBoyState<Running>),
        Sliding(RedHatBoyState<Sliding>),
    }
    impl RedHatBoyState<Jumping> {
        pub fn frame_name(&self) -> &str {
            JUMPING_FRAME_NAME
        }
        pub fn update(mut self) -> JumpingEndState {
            self.context = self.context.update(JUMPING_FRAMES);
            if self.context.position.y >= FLOOR {
                JumpingEndState::Landing(self.land())
            } else {
                JumpingEndState::Jumping(self)
            }
        }
        pub fn land(self) -> RedHatBoyState<Running> {
            RedHatBoyState {
                context: self.context.reset_frame(),
                _state: Running {},
            }
        }
    }

    pub enum JumpingEndState {
        Landing(RedHatBoyState<Running>),
        Jumping(RedHatBoyState<Jumping>),
    }
    #[derive(Copy, Clone)]
    pub struct Idle;
    #[derive(Copy, Clone)]
    pub struct Running;
    #[derive(Copy, Clone)]
    pub struct Sliding;
    #[derive(Copy, Clone)]
    pub struct Jumping;
}
