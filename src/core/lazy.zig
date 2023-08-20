pub fn Lazy(comptime T: type, comptime R: type) type {
    return struct {
        var cached: ?R = undefined;

        pub fn get() R {
            if (cached) |found| {
                return found;
            }
            var result = T.init();
            cached = result;
            return result;
        }
    };
}
