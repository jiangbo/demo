// const std = @import("std");
// const world = @import("world.zig");
// const print = std.debug.print;

// pub fn  executeGet(noun :[] const u8) void
// {
//    OBJECT *obj = world.getVisible("what you want to get", noun);
//    if (obj == NULL)
//    {
//       // already handled by getVisible
//    }
//    else if (obj == player)
//    {
//       printf("You should not be doing that to yourself.\n");
//    }
//    else if (obj->location == player)
//    {
//       printf("You already have %s.\n", obj->description);
//    }
//    else if (obj->location == guard)
//    {
//       printf("You should ask %s nicely.\n", obj->location->description);
//    }
//    else
//    {
//       moveObject(obj, player);
//    }
// }
