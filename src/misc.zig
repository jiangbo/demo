const print = @import("std").debug.print;
const object = @import("object.zig");

fn listObjectsAtLocation(location: *object.Object) i32 {
    var count: i32 = 0;
    for (object.objs) |obj| {
        if (obj != object.player and obj.location == location) {
            count += 1;
            if (count == 0) {
                print("You see:\n", .{});
            }
            print("{s}\n", .{obj.description});
        }
    }
    return count;
}
