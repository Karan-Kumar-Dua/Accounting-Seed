/**
 * Provides a generalized class mocking for used in
 * many testing situations.
 */
@IsTest
public class GenericMock implements System.StubProvider {
    // method name to fifo list of responses
    private Map<String,List<Object>> resps;

    public GenericMock() {
        this.resps = new Map<String,List<Object>>();
    }

    // Add responses for each the method you need to mock.
    // If the same method will be called multiple times, 
    // add the responses in the order they will be called
    public void registerResponse(String methodName, Object response) {
        if (!resps.containsKey(methodName)) {
            resps.put(methodName, new List<Object>());
        }
        resps.get(methodName).add(response);
    }

    // Implements the StubProvider interface
    public Object handleMethodCall(
            Object stubbedObject,
            String stubbedMethodName,
            Type returnType,
            List<Type> listOfParamTypes,
            List<String> listOfParamNames,
            List<Object> listOfArgs) {

        // if nothing return null
        if (!resps.containsKey(stubbedMethodName) 
                || resps.get(stubbedMethodName) == null 
                || resps.get(stubbedMethodName).isEmpty()) {
            return null;
        }

        // get the next response in the fifo list
        Object o = resps.get(stubbedMethodName).remove(0);
        
        // if the reponse was an exception, throw it
        if (o instanceof Exception) {
            throw (Exception) o;
        }
        // otherwise, it is a normal return type
        return o;
    }
}