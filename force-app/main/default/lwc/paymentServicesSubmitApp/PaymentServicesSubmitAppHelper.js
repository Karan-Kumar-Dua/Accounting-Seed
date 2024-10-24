export default class PaymentServicesSubmitAppHelper{

    async remoteCall(methodName, params = {}, thisArg) {
        let result;
        let isFailed = false;
        let errors;
        try{
            result  = await methodName(params);
        }
        catch(err) {
            isFailed = true;
            thisArg.processError(err);
            errors = thisArg.error;
        }
        return new Promise((resolve, reject) => {
            if (isFailed) {
               reject(errors);
            } else {
                resolve(result);
            }
        });
    }

}