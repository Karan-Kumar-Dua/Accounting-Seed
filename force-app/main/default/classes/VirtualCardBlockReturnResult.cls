public class VirtualCardBlockReturnResult {

    public class Description {
        public String error;
    }

    public String correlationId;
    public Result result;

    public class Result {
        public String errorType;
        public Description description;
    }


    public static VirtualCardBlockReturnResult parse(String json) {
        return (VirtualCardBlockReturnResult) System.JSON.deserialize(json, VirtualCardBlockReturnResult.class);
    }
}