@isTest
public with sharing class BDCMocker {
    
@TestVisible
public static final String CONNECTOR_EXCEPTION = 'CONNECTOR_EXCEPTION';

@TestVisible
public static final String CONVERTER_EXCEPTION = 'CONVERTER_EXCEPTION';

public static AbstractBDCRouter createMockRouter(boolean connectorException, boolean converterException, boolean errorResponseCode){
    AbstractBDCRouter router;

    //stub converter
    BDCConverterMock mockConverter = new BDCConverterMock(testBDCDataModel(), converterException );
    AbstractBDCConverter converter = (AbstractBDCConverter) Test.createStub(AbstractBDCConverter.class, mockConverter);

    //stub connector 
    BDCConnectorMock mockConnector = new BDCConnectorMock(testBDCHttpResponses(errorResponseCode), connectorException);
    AbstractBDCConnector connector = (AbstractBDCConnector) Test.createStub(AbstractBDCConnector.class, mockConnector);

    //stub router, mocked connector and mocked converter are returned when mocked router methods are called
    BDCRouterMock mockRouter = new BDCRouterMock(connector, converter);
    router = (AbstractBDCRouter)Test.createStub(AbstractBDCRouter.class, mockRouter);


    return router;
}
    
public class BDCConverterMock implements System.StubProvider {
    public BDCDataModel output;
    public boolean throwException = false;

    public BDCConverterMock(BDCDataModel output, boolean throwException) {
        this.output = output;
    }

    public Object handleMethodCall(
            Object stubbedObject,
            String stubbedMethodName,
            Type returnType,
            List<Type> listOfParamTypes,
            List<String> listOfParamNames,
            List<Object> listOfArgs) {

        if(throwException){
            throw new BDCService.BDCException(CONVERTER_EXCEPTION);
        }

        switch on stubbedMethodName {
            when 'convertFinancialInstitutions' {		
                return output.bdcFinancialInstitutions;
            }
            when 'convertTransactions'{
                return output.bdcTransactions;
            }
            when 'convertTransactionCount'{
                return 100;
            }
            when 'convertAccounts'{
                return output.bdcAccounts;
            }
            when 'convertFinancialInstitutionIdentities'{
                return output.bdcFinancialInstitutionIdentities;
            }
            when else{
                return output;
            }
        }
 
    }
}

public class BDCConnectorMock implements System.StubProvider {
    public List<HttpResponse> output;
    public boolean throwException = false;

    public BDCConnectorMock(List<HttpResponse> output, boolean throwException) {
        this.output = output;
        this.throwException = throwException;
    }

    public Object handleMethodCall(
            Object stubbedObject,
            String stubbedMethodName,
            Type returnType,
            List<Type> listOfParamTypes,
            List<String> listOfParamNames,
            List<Object> listOfArgs) {

        //mock results here
        if(throwException){
            throw new BDCService.BDCException(CONNECTOR_EXCEPTION);
        }
        return output;
    }
}

public class BDCRouterMock implements System.StubProvider {

    AbstractBDCConnector connector;
    AbstractBDCCOnverter converter;

    public BDCRouterMock(AbstractBDCConnector connector, AbstractBDCCOnverter converter) {
        this.connector = connector;
        this.converter = converter;
    }

    public Object handleMethodCall(
            Object stubbedObject,
            String stubbedMethodName,
            Type returnType,
            List<Type> listOfParamTypes,
            List<String> listOfParamNames,
            List<Object> listOfArgs) {

        if(stubbedMethodName == 'getConnector'){
            return connector;
        }
        if(stubbedMethodName == 'getConverter'){
            return converter;
        }
        
        return null;
    }
}


//Test Data

    @isTest
    public static BDC_Binding__c testBDCBinding(){
        BDC_Binding__c testBinding = new BDC_Binding__c();
        testBinding.Name = 'Yodlee';
        testBinding.To__c = 'YodleeBDCRouter';
        testBinding.Type__c = 'AbstractBDCRouter';
        testBinding.Is_Active__c = true;

        insert testBinding;
        return testBinding;
    }

    public static BDCDataModel testBDCDataModel(){
        BDCDataModel model = new BDCDataModel();

        //financial institutions
        List<BDCFinancialInstitution> financialInstitutions = new List<BDCFinancialInstitution>();
        BDCFinancialInstitution financialInstitution = new BDCFinancialInstitution();
        financialInstitution.id = 'AS_Financial Inst';
        financialInstitution.name = 'AS Financial Inst';
        financialInstitutions.add(financialInstitution);

        BDCFinancialInstitution financialInstitution2 = new BDCFinancialInstitution();
        financialInstitution2.id = 'Test_Bank';
        financialInstitution2.name = 'Test Bank';
        financialInstitutions.add(financialInstitution2);

        model.bdcFinancialInstitutions = financialInstitutions;

        //financial institution identities
        List<BDCFinancialInstitutionIdentity> financialInstitutionIdentities = new List<BDCFinancialInstitutionIdentity>();
        BDCFinancialInstitutionIdentity financialInstitutionIdentity = new BDCFinancialInstitutionIdentity();
        financialInstitutionIdentity.id = 'yqRQV73LQMt95BJ85PKGIzBnxkPkdoFy3NKa9';
        financialInstitutionIdentity.financialInstitutionId = 'AS_Bank';
        financialInstitutionIdentities.add(financialInstitutionIdentity);

        model.bdcFinancialInstitutionIdentities = financialInstitutionIdentities;

        //accounts
        list<BDCAccount> bdcAccounts = new list<BDCAccount>();
        for (BDCFinancialInstitutionIdentity FII : financialInstitutionIdentities){
            for (Integer i = 0; i < 2; i++) {
                BDCAccount bdcAccount = new BDCAccount();
                bdcAccount.Id = FII.Id + '_Acc_' + String.valueOf(i);
                bdcAccount.financialInstitutionIdentity = FII.Id;
                bdcAccount.name='Bank Account ' + String.valueOf(i);
                bdcAccount.accountType = 'bank';
                bdcAccount.status = 'ACTIVE';
                bdcAccount.maskedAccountNumber = '*****5555';
                bdcAccounts.add(bdcAccount);
            }
        }
        model.bdcAccounts = bdcAccounts;

        return model;
    }

    public static List<HttpResponse> testBDCHttpResponses(boolean errorResponseCode){
        List<HttpResponse> responses = new List<HttpResponse>();
        
        HttpResponse response = new HttpResponse();
        
        if(errorResponseCode){
            response.setStatusCode(400);
            response.setBody('test response body');
            response.setStatus('FAIL');
        }else{
            response.setStatusCode(200);
            response.setBody('test response body');
            response.setStatus('SUCCESS');
    
        }
        responses.add(response);

        return responses;
    }
}