const std = @import("std");
const c = @import("c.zig");

pub const App = struct {
    width: c_int = 1280,
    height: c_int = 720,
    window: *c.SDL_Window = undefined,
    renderer: *c.SDL_Renderer = undefined,

    pub fn init(self: *App) void {
        if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) sdlPanic();
        if (c.TTF_Init() < 0) sdlPanic();

        const center = c.SDL_WINDOWPOS_CENTERED;
        self.window = c.SDL_CreateWindow("俄罗斯方块", center, center, //
            self.width, self.height, c.SDL_WINDOW_SHOWN) orelse sdlPanic();

        self.renderer = c.SDL_CreateRenderer(self.window, -1, 0) //
        orelse sdlPanic();
    }

    pub fn run(self: *App) void {
        _ = self;
     
const start = c.SDL_GetTicks();	

    mainLoop: while (true) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            if (event.type == c.SDL_QUIT)
                break :mainLoop;
        }

        _ = c.SDL_SetRenderDrawColor(app.renderer, 96, 128, 255, 255);
        _ = c.SDL_RenderClear(app.renderer);

        c.SDL_RenderPresent(app.renderer);
    }


			if(event.type == SDL_KEYDOWN)
			{
				if(event.key.keysym.sym == SDLK_ESCAPE)
				{
					bDone = true;
				}
				else if( event.key.keysym.sym == SDLK_SPACE )
				{
					gameInput.bStart = true;
				}
				else if( event.key.keysym.sym == SDLK_LEFT )
				{
					gameInput.bMoveLeft = true;
				}
				else if( event.key.keysym.sym == SDLK_RIGHT )
				{
					gameInput.bMoveRight = true;
				}
				else if( event.key.keysym.sym == SDLK_z )
				{
					gameInput.bRotateClockwise = true;
				}
				else if( event.key.keysym.sym == SDLK_x )
				{
					gameInput.bRotateAnticlockwise = true;
				}
				else if( event.key.keysym.sym == SDLK_UP )
				{
					gameInput.bHardDrop = true;
				}
				else if( event.key.keysym.sym == SDLK_DOWN )
				{
					gameInput.bSoftDrop = true;
				}
				else if( event.key.keysym.sym == SDLK_p )
				{
					gameInput.bPause = true;
				}
			}
		}

		Uint32 currentTimeMs = SDL_GetTicks();
	
		auto deltaTime = currentTime - lastTime;
		std::chrono::microseconds deltaTimeMicroseconds = std::chrono::duration_cast<std::chrono::microseconds>(deltaTime);
		float deltaTimeSeconds = 0.000001f * (float)deltaTimeMicroseconds.count();
		lastTime = currentTime;

		m_pGame->Update( gameInput, deltaTimeSeconds );

		m_pRenderer->Clear();
		m_pGame->Draw( *m_pRenderer );
		m_pRenderer->Present();    
    }

    pub fn deinit(self: *App) void {
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        c.TTF_Quit();
        c.SDL_Quit();
    }
};

fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, c.SDL_GetError());
    @panic(std.mem.sliceTo(str orelse "unknown error", 0));
}
