export default class ErrorUtils {

  static reduceErrors(errors) {
    if (!Array.isArray(errors)) {
      errors = [errors];
    }

    return (
      errors
        // Remove null/undefined items
        .filter(error => !!error)
        // Extract an error message
        .map(error => {
          // UI API read errors
          if (Array.isArray(error.body)) {
            return error.body.map(e => e.message);
          }
          // UI API DML, Apex and network errors
          else if (error.body && typeof error.body.message === 'string') {
              let returnErrorMessage = error.body.message;
              let exceptionName = 'FIELD_CUSTOM_VALIDATION_EXCEPTION';
              if ((error.body.message).includes(exceptionName)) {
                  let exceptionIndex = (error.body.message).indexOf(exceptionName);
                  let substringAfterException = (error.body.message).substring(exceptionIndex + exceptionName.length + 1);
                  returnErrorMessage = (substringAfterException.includes(':'))?substringAfterException.split(':')[0]: substringAfterException;
              }
            return returnErrorMessage;
          }
          // JS errors
          else if (typeof error.message === 'string') {
            return error.message;
          }
          // streaming API errors
          else if (typeof error.error === 'string') {
            return error.error;
          }
          // Unknown error shape so try HTTP status text
          return error.statusText;
        })
        // Flatten
        .reduce((prev, curr) => prev.concat(curr), [])
        // Remove empty strings
        .filter(message => !!message)
    );
  }

  static processError(extError) {
    let isError;
    let error;
    try {
      const errorData = JSON.parse(extError.body.message);
      error = errorData.message;
      switch (errorData.code) {
        case 'CRUD_FLS_READ':
          isError = true;
          break;
        case 'UNKNOWN':
          isError = true;
          break;
        default:
          isError = false;
      }
    } catch (e) {
      if (extError.body && extError.body.message) {
        error = extError.body.message;
        isError = true;
      }
      else {
        error = extError;
      }
    }
    return { isError, error };
  }

  static processRecordApiErrors(errorBody) {
      let topErrors = [];
      let fieldErrors = {};
      errorBody && errorBody.output && (
          errorBody.output.errors && errorBody.output.errors.forEach(error => {
              topErrors.push({
                  message: error.message,
                  errorCode: error.errorCode
              })
          }),
          errorBody.output.fieldErrors && (fieldErrors = {...errorBody.output.fieldErrors})
      );

      return { topErrors, fieldErrors };
  }
}