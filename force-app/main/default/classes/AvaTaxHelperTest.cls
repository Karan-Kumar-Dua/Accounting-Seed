@isTest
public class AvaTaxHelperTest {

    @TestSetup
    static void setup(){
        TestDataSuite testData = TestDataSuite.getInstance(true);
        testData.createBillings();
    }

    //a helper method that retrieves a billing Id that has address information
    //used to requery via the AvaTaxHelper, which is a function intended to return the fields necessary to use AvaTaxHelper functions
    private static Id getBillingWithAddressInfo() {
        //find a billing Id that has shipping info
        Billing__c aBilling = [
            SELECT
                Id
            FROM Billing__c
            WHERE Shipping_Street__c != null
            LIMIT 1
        ];

        return aBilling.Id;
    }

    //tests that the correct address Model is returned from a billing with taxAddressMode = Shipment
    @IsTest
    public static void testGetAddresses_Billing_Shipment() {
        System.Test.startTest();
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {

            //set the taxAddress mode and the default origin address
            testData.createTaxGroups().enableAvaTaxCalculation();

            Billing__c aBilling = AvaTaxHelper.queryBillingById(new Set<Id>{getBillingWithAddressInfo()}, false)[0];

            //call getAddresses on a billing
            AvaTaxService.AddressesModel addrModel = AvaTaxHelper.getAddresses(AvaTaxHelper.getOriginAddressInfo(aBilling), AvaTaxHelper.getDestinationAddressInfo(aBilling), aBilling);
            System.Test.stopTest();

            //Compare the Origin to the default address
            System.assertEquals(testData.addressObjects[0].Street__c, addrModel.shipFrom.line1);
            System.assertEquals(testData.addressObjects[0].City__c, addrModel.shipFrom.city);
            System.assertEquals(testData.addressObjects[0].State_Province__c, addrModel.shipFrom.region);
            System.assertEquals(testData.addressObjects[0].Postal_Code__c, addrModel.shipFrom.postalCode);
            System.assertEquals(testData.addressObjects[0].Country_Code__c, addrModel.shipFrom.country);

            //Compare the Destination to the Billing's shipping address
            System.assertEquals(aBilling.Shipping_Street__c, addrModel.shipTo.line1);
            System.assertEquals(aBilling.Shipping_City__c, addrModel.shipTo.city);
            System.assertEquals(aBilling.Shipping_State__c, addrModel.shipTo.region);
            System.assertEquals(aBilling.Shipping_PostalCode__c, addrModel.shipTo.postalCode);
            System.assertEquals(aBilling.Shipping_Country__c, addrModel.shipTo.country);

            //assure the single address has not been filled
            System.assertEquals(null, addrModel.singleLocation);
        }
    }

    //tests that the correct address Model is returned from a billing with taxAddressMode = POD
    @IsTest
    public static void testGetAddresses_Billing_POD() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            System.Test.startTest();
            //set the taxAddress mode and the default origin address
            testData.createTaxGroups().enableAvaTaxCalculation();
            Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(testData.ledgers[0].Id);

            Tax_Settings__c taxSetting = [SELECT Id, Sales_Tax_Calculation_Mode__c FROM Tax_Settings__c WHERE Id = :selectedLedger.Tax_Settings__c LIMIT 1];
            taxSetting.Sales_Tax_Calculation_Mode__c = 'Point of Destination';
            update taxSetting;

            Billing__c aBilling = AvaTaxHelper.queryBillingById(new Set<Id>{getBillingWithAddressInfo()}, false)[0];


            //call getAddresses on a billing
            AvaTaxService.AddressesModel addrModel = AvaTaxHelper.getAddresses(AvaTaxHelper.getOriginAddressInfo(aBilling), AvaTaxHelper.getDestinationAddressInfo(aBilling), aBilling);
            System.Test.stopTest();

            //assure the other address info has not been filled
            System.assertEquals(null, addrModel.shipFrom);
            System.assertEquals(null, addrModel.shipTo);

            //assure shipping address is the single location
            System.assertEquals(aBilling.Shipping_Street__c, addrModel.singleLocation.line1);
            System.assertEquals(aBilling.Shipping_City__c, addrModel.singleLocation.city);
            System.assertEquals(aBilling.Shipping_State__c, addrModel.singleLocation.region);
            System.assertEquals(aBilling.Shipping_PostalCode__c, addrModel.singleLocation.postalCode);
            System.assertEquals(aBilling.Shipping_Country__c, addrModel.singleLocation.country);
        }
    }

    //tests that the correct address Model is returned from a billing with taxAddressMode = POS
    @IsTest
    public static void testGetAddresses_Billing_POS() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            System.Test.startTest();
            //set the taxAddress mode and the default origin address
            testData.createTaxGroups().enableAvaTaxCalculation();
            Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(testData.ledgers[0].Id);

            Tax_Settings__c taxSetting = [SELECT Id, Sales_Tax_Calculation_Mode__c FROM Tax_Settings__c WHERE Id = :selectedLedger.Tax_Settings__c LIMIT 1];
            taxSetting.Sales_Tax_Calculation_Mode__c = 'Point of Sale';
            update taxSetting;

            Billing__c aBilling = AvaTaxHelper.queryBillingById(new Set<Id>{getBillingWithAddressInfo()}, false)[0];

            //call getAddresses on a billing
            AvaTaxService.AddressesModel addrModel = AvaTaxHelper.getAddresses(AvaTaxHelper.getOriginAddressInfo(aBilling), AvaTaxHelper.getDestinationAddressInfo(aBilling), aBilling);
            System.Test.stopTest();

            //assure the other address info has not been filled
            System.assertEquals(null, addrModel.shipFrom);
            System.assertEquals(null, addrModel.shipTo);

            //assure shipping address is the single location
            System.assertEquals(testData.addressObjects[0].Street__c, addrModel.singleLocation.line1);
            System.assertEquals(testData.addressObjects[0].City__c, addrModel.singleLocation.city);
            System.assertEquals(testData.addressObjects[0].State_Province__c, addrModel.singleLocation.region);
            System.assertEquals(testData.addressObjects[0].Postal_Code__c, addrModel.singleLocation.postalCode);
            System.assertEquals(testData.addressObjects[0].Country_Code__c, addrModel.singleLocation.country);
        }
    }

    //tests that the correct address Model is returned from a billing with taxAddressMode = Shipment and both addresses have been overwritten
    @IsTest
    public static void testGetAddresses_Billing_Shipment_BothOverride() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            System.Test.startTest();
            //set the taxAddress mode and the default origin address
            testData = testData
                    .createTaxGroups()
                    .enableAvaTaxCalculation();

            //get some addresses to use as override addresses
            Address__c testOrigin = testData.addressObjects[0];
            Address__c testDest = testData.addressObjects[1];

            //set the addresses on the billing
            Id targetBillingId = getBillingWithAddressInfo();
            Billing__c aBilling = new Billing__c(id=targetBillingId);
            aBilling.Origin_Address_Override__c = testOrigin.Id;
            aBilling.Destination_Address_Override__c = testDest.Id;
            update new List<Billing__c>{aBilling};
            //requery for updates
            aBilling = AvaTaxHelper.queryBillingById(new Set<Id>{aBilling.Id}, false)[0];


            //call getAddresses on a billing
            AvaTaxService.AddressesModel addrModel = AvaTaxHelper.getAddresses(AvaTaxHelper.getOriginAddressInfo(aBilling), AvaTaxHelper.getDestinationAddressInfo(aBilling), aBilling);
            System.Test.stopTest();

            //Compare the Origin override to the shipFrom address
            System.assertEquals(testOrigin.Street__c, addrModel.shipFrom.line1);
            System.assertEquals(testOrigin.City__c, addrModel.shipFrom.city);
            System.assertEquals(testOrigin.State_Province__c, addrModel.shipFrom.region);
            System.assertEquals(testOrigin.Postal_Code__c, addrModel.shipFrom.postalCode);
            System.assertEquals(testOrigin.Country_Code__c, addrModel.shipFrom.country);

            //Compare the Destination Override to the shipTo address
            System.assertEquals(testDest.Street__c, addrModel.shipTo.line1);
            System.assertEquals(testDest.City__c, addrModel.shipTo.city);
            System.assertEquals(testDest.State_Province__c, addrModel.shipTo.region);
            System.assertEquals(testDest.Postal_Code__c, addrModel.shipTo.postalCode);
            System.assertEquals(testDest.Country_Code__c, addrModel.shipTo.country);

            //assure the single address has not been filled
            System.assertEquals(null, addrModel.singleLocation);
        }
    }

    //tests that the correct address Model is returned from a billing with taxAddressMode = Shipment and the Origin address has been overwritten
    @IsTest
    public static void testGetAddresses_Billing_Shipment_OriginOverride() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            System.Test.startTest();
            //set the taxAddress mode and the default origin address
            testData = testData
                    .createTaxGroups()
                    .enableAvaTaxCalculation();

            //get some addresses to use as override addresses
            Address__c testOrigin = testData.addressObjects[0];

            //set the addresses on the billing
            Id targetBillingId = getBillingWithAddressInfo();
            Billing__c aBilling = new Billing__c(id=targetBillingId);
            aBilling.Origin_Address_Override__c = testOrigin.Id;
            update new List<Billing__c>{aBilling};
            //requery for updates
            aBilling = AvaTaxHelper.queryBillingById(new Set<Id>{aBilling.Id}, false)[0];


            //call getAddresses on a billing
            AvaTaxService.AddressesModel addrModel = AvaTaxHelper.getAddresses(AvaTaxHelper.getOriginAddressInfo(aBilling), AvaTaxHelper.getDestinationAddressInfo(aBilling), aBilling);
            System.Test.stopTest();

            //Compare the Origin override to the shipFrom address
            System.assertEquals(testOrigin.Street__c, addrModel.shipFrom.line1);
            System.assertEquals(testOrigin.City__c, addrModel.shipFrom.city);
            System.assertEquals(testOrigin.State_Province__c, addrModel.shipFrom.region);
            System.assertEquals(testOrigin.Postal_Code__c, addrModel.shipFrom.postalCode);
            System.assertEquals(testOrigin.Country_Code__c, addrModel.shipFrom.country);

            //Compare the billing's shipping address to the shipTo address
            System.assertEquals(aBilling.Shipping_Street__c, addrModel.shipTo.line1);
            System.assertEquals(aBilling.Shipping_City__c, addrModel.shipTo.city);
            System.assertEquals(aBilling.Shipping_State__c, addrModel.shipTo.region);
            System.assertEquals(aBilling.Shipping_PostalCode__c, addrModel.shipTo.postalCode);
            System.assertEquals(aBilling.Shipping_Country__c, addrModel.shipTo.country);

            //assure the single address has not been filled
            System.assertEquals(null, addrModel.singleLocation);
        }
    }

    //tests that the correct address Model is returned from a billing with taxAddressMode = POS and the Origin Address has been overwritten
    @IsTest
    public static void testGetAddresses_Billing_POS_OriginOverride() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            System.Test.startTest();
            //set the taxAddress mode and the default origin address
            testData = testData
                    .createTaxGroups()
                    .enableAvaTaxCalculation();
            Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(testData.ledgers[0].Id);

            Tax_Settings__c taxSetting = [SELECT Id, Sales_Tax_Calculation_Mode__c FROM Tax_Settings__c WHERE Id = :selectedLedger.Tax_Settings__c LIMIT 1];
            taxSetting.Sales_Tax_Calculation_Mode__c = 'Point of Sale';
            update taxSetting;

            //get some addresses to use as override addresses
            Address__c testOrigin = testData.addressObjects[0];

            //set the addresses on the billing
            Id targetBillingId = getBillingWithAddressInfo();
            Billing__c aBilling = new Billing__c(id=targetBillingId);
            aBilling.Origin_Address_Override__c = testOrigin.Id;
            update new List<Billing__c>{aBilling};
            //requery for updates
            aBilling = AvaTaxHelper.queryBillingById(new Set<Id>{aBilling.Id}, false)[0];


            //call getAddresses on a billing
            AvaTaxService.AddressesModel addrModel = AvaTaxHelper.getAddresses(AvaTaxHelper.getOriginAddressInfo(aBilling), AvaTaxHelper.getDestinationAddressInfo(aBilling), aBilling);
            System.Test.stopTest();

            //assure the other address info has not been filled
            System.assertEquals(null, addrModel.shipFrom);
            System.assertEquals(null, addrModel.shipTo);

            //assure shipping address is the single location
            System.assertEquals(testOrigin.Street__c, addrModel.singleLocation.line1);
            System.assertEquals(testOrigin.City__c, addrModel.singleLocation.city);
            System.assertEquals(testOrigin.State_Province__c, addrModel.singleLocation.region);
            System.assertEquals(testOrigin.Postal_Code__c, addrModel.singleLocation.postalCode);
            System.assertEquals(testOrigin.Country_Code__c, addrModel.singleLocation.country);
        }
    }

    //tests that the correct address Model is returned from a billing with taxAddressMode = POD and the Destination Address has been overwritten
    @IsTest
    public static void testGetAddresses_Billing_POD_DestinationOverride() {
        TestDataSuite testData = TestDataSuite.getInstance();
        System.runAs(testData.users.get(1)) {
            System.Test.startTest();
            //set the taxAddress mode and the default origin address
            testData = testData
                    .createTaxGroups()
                    .enableAvaTaxCalculation();

            Ledger__c selectedLedger = LedgerHandler.getInstanceWithSharing(true).getLedgerById(testData.ledgers[0].Id);

            Tax_Settings__c taxSetting = [SELECT Id, Sales_Tax_Calculation_Mode__c FROM Tax_Settings__c WHERE Id = :selectedLedger.Tax_Settings__c LIMIT 1];
            taxSetting.Sales_Tax_Calculation_Mode__c = 'Point of Destination';
            update taxSetting;

            //get some addresses to use as override addresses
            Address__c testDest = testData.addressObjects[1];

            //set the addresses on the billing
            Id targetBillingId = getBillingWithAddressInfo();
            Billing__c aBilling = new Billing__c(id=targetBillingId);
            aBilling.Destination_Address_Override__c = testDest.Id;
            update new List<Billing__c>{aBilling};
            //requery for updates
            aBilling = AvaTaxHelper.queryBillingById(new Set<Id>{aBilling.Id}, false)[0];


            //call getAddresses on a billing
            AvaTaxService.AddressesModel addrModel = AvaTaxHelper.getAddresses(AvaTaxHelper.getOriginAddressInfo(aBilling), AvaTaxHelper.getDestinationAddressInfo(aBilling), aBilling);
            System.Test.stopTest();

            //assure the other address info has not been filled
            System.assertEquals(null, addrModel.shipFrom);
            System.assertEquals(null, addrModel.shipTo);

            //assure shipping address is the single location
            System.assertEquals(testDest.Street__c, addrModel.singleLocation.line1);
            System.assertEquals(testDest.City__c, addrModel.singleLocation.city);
            System.assertEquals(testDest.State_Province__c, addrModel.singleLocation.region);
            System.assertEquals(testDest.Postal_Code__c, addrModel.singleLocation.postalCode);
            System.assertEquals(testDest.Country_Code__c, addrModel.singleLocation.country);
        }
    }
}