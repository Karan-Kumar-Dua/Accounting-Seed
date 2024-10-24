@IsTest
public with sharing class YodleeBDCTest {
    
    public static Final String ACCOUNTS_FROM_FID_TEST_JSON = '{' +
        '"account": [' +
            '{' +
            '"CONTAINER": "bank",' +
            '"providerAccountId": 21759841,' +
            '"accountName": "Dag Saving Plus",' +
            '"accountStatus": "ACTIVE",' +
            '"accountNumber": "4197",' +
            '"aggregationSource": "USER",' +
            '"isAsset": true,' +
            '"balance": { "currency": "USD", "amount": 305 },' +
            '"id": 29462280,' +
            '"includeInNetWorth": true,' +
            '"providerId": "16441",' +
            '"providerName": "Dag Site",' +
            '"isManual": false,' +
            '"availableBalance": { "currency": "USD", "amount": 105 },' +
            '"currentBalance": { "currency": "USD", "amount": 305 },' +
            '"accountType": "SAVINGS",' +
            '"displayedName": "Robin",' +
            '"createdDate": "2022-07-20T09:21:46Z",' +
            '"classification": "PERSONAL",' +
            '"lastUpdated": "2022-08-01T06:06:39Z",' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"additionalStatus": "AVAILABLE_DATA_RETRIEVED",' +
                '"updateEligibility": "ALLOW_UPDATE",' +
                '"lastUpdated": "2022-08-01T06:06:39Z",' +
                '"lastUpdateAttempt": "2022-08-01T06:06:39Z",' +
                '"nextUpdateScheduled": "2022-08-01T19:01:33Z"' +
                '}' +
            '],' +
            '"autoRefresh": {' +
                '"status": "ENABLED",' +
                '"additionalStatus": "SCHEDULED",' +
                '"asOfDate": "2022-07-20T09:21:47Z"' +
            '}' +
            '},' +
            '{' +
            '"CONTAINER": "bank",' +
            '"providerAccountId": 21759841,' +
            '"accountName": "Dag Fixed Term Deposit",' +
            '"accountStatus": "ACTIVE",' +
            '"accountNumber": "88108044789881",' +
            '"aggregationSource": "USER",' +
            '"isAsset": true,' +
            '"balance": { "currency": "USD", "amount": 27517.34 },' +
            '"id": 29462279,' +
            '"includeInNetWorth": true,' +
            '"providerId": "16441",' +
            '"providerName": "Dag Site",' +
            '"isManual": false,' +
            '"currentBalance": { "currency": "USD", "amount": 27517.34 },' +
            '"accountType": "CD",' +
            '"displayedName": "Robin",' +
            '"createdDate": "2022-07-20T09:21:46Z",' +
            '"classification": "PERSONAL",' +
            '"interestRate": 0.01,' +
            '"lastUpdated": "2022-08-01T06:06:39Z",' +
            '"maturityAmount": { "currency": "USD", "amount": 36000 },' +
            '"maturityDate": "2021-05-03",' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"additionalStatus": "AVAILABLE_DATA_RETRIEVED",' +
                '"updateEligibility": "ALLOW_UPDATE",' +
                '"lastUpdated": "2022-08-01T06:06:39Z",' +
                '"lastUpdateAttempt": "2022-08-01T06:06:39Z",' +
                '"nextUpdateScheduled": "2022-08-01T19:01:33Z"' +
                '}' +
            '],' +
            '"autoRefresh": {' +
                '"status": "ENABLED",' +
                '"additionalStatus": "SCHEDULED",' +
                '"asOfDate": "2022-07-20T09:21:47Z"' +
            '}' +
            '},' +
            '{' +
            '"CONTAINER": "bank",' +
            '"providerAccountId": 21759841,' +
            '"accountName": "Dag Checking Account",' +
            '"accountStatus": "ACTIVE",' +
            '"accountNumber": "2345",' +
            '"aggregationSource": "USER",' +
            '"isAsset": true,' +
            '"balance": { "currency": "USD", "amount": 1600 },' +
            '"id": 29462278,' +
            '"includeInNetWorth": true,' +
            '"providerId": "16441",' +
            '"providerName": "Dag Site",' +
            '"isManual": false,' +
            '"availableBalance": { "currency": "USD", "amount": 1500 },' +
            '"currentBalance": { "currency": "USD", "amount": 1600 },' +
            '"accountType": "CHECKING",' +
            '"displayedName": "Robin",' +
            '"createdDate": "2022-07-20T09:21:46Z",' +
            '"classification": "PERSONAL",' +
            '"interestRate": 0.01,' +
            '"lastUpdated": "2022-08-01T06:06:39Z",' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"additionalStatus": "AVAILABLE_DATA_RETRIEVED",' +
                '"updateEligibility": "ALLOW_UPDATE",' +
                '"lastUpdated": "2022-08-01T06:06:39Z",' +
                '"lastUpdateAttempt": "2022-08-01T06:06:39Z",' +
                '"nextUpdateScheduled": "2022-08-01T19:01:33Z"' +
                '}' +
            '],' +
            '"autoRefresh": {' +
                '"status": "ENABLED",' +
                '"additionalStatus": "SCHEDULED",' +
                '"asOfDate": "2022-07-20T09:21:47Z"' +
            '}' +
            '},' +
            '{' +
            '"CONTAINER": "bank",' +
            '"providerAccountId": 21759841,' +
            '"accountName": "Dag Checking Account1",' +
            '"accountStatus": "ACTIVE",' +
            '"accountNumber": "23456",' +
            '"aggregationSource": "USER",' +
            '"isAsset": true,' +
            '"balance": { "currency": "USD", "amount": 1600 },' +
            '"id": 29462270,' +
            '"includeInNetWorth": true,' +
            '"providerId": "16441",' +
            '"providerName": "Dag Site",' +
            '"isManual": false,' +
            '"availableBalance": { "currency": "USD", "amount": 1500 },' +
            '"currentBalance": { "currency": "USD", "amount": 1600 },' +
            '"accountType": "SAVING",' +
            '"displayedName": "Robin",' +
            '"createdDate": "2022-07-20T09:21:46Z",' +
            '"classification": "PERSONAL",' +
            '"interestRate": 0.01,' +
            '"lastUpdated": "2022-08-01T06:06:39Z",' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"additionalStatus": "AVAILABLE_DATA_RETRIEVED",' +
                '"updateEligibility": "ALLOW_UPDATE",' +
                '"lastUpdated": "2022-08-01T06:06:39Z",' +
                '"lastUpdateAttempt": "2022-08-01T06:06:39Z",' +
                '"nextUpdateScheduled": "2022-08-01T19:01:33Z"' +
                '}' +
            '],' +
            '"autoRefresh": {' +
                '"status": "ENABLED",' +
                '"additionalStatus": "SCHEDULED",' +
                '"asOfDate": "2022-07-20T09:21:47Z"' +
            '}' +
            '}' +
        ']' +
    '}';
    
    public static Final String FINANCIAL_INSTITUTIONS_ID_TEST_JSON = '{' +
        '"provider": [' +
            '{' +
            '"PRIORITY": "SEARCH",' +
            '"id": 16441,' +
            '"name": "AS Financial Inst",' +
            '"loginUrl": "http://64.14.28.129/dag/index.do",' +
            '"baseUrl": "http://64.14.28.129/dag/index.do",' +
            '"favicon": "https://yodlee-1.hs.llnwd.net/v1/FAVICON/FAV_16441.SVG",' +
            '"logo": "https://yodlee-1.hs.llnwd.net/v1/LOGO/LOGO_16441_1_2.SVG",' +
            '"status": "Supported",' +
            '"isConsentRequired": false,' +
            '"authType": "CREDENTIALS",' +
            '"languageISOCode": "EN",' +
            '"primaryLanguageISOCode": "EN",' +
            '"countryISOCode": "US",' +
            '"lastModified": "2022-06-22T10:33:00Z",' +
            '"forgetPasswordUrl": "http://64.14.28.129/dag/index.do",' +
            '"isAutoRefreshEnabled": true,' +
            '"capability": [' +
                '{ "name": "CHALLENGE_DEPOSIT_VERIFICATION", "container": ["bank"] }' +
            '],' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"attribute": [' +
                    '{' +
                    '"name": "ACCOUNT_DETAILS",' +
                    '"container": ["bank", "investment", "creditCard"]' +
                    '},' +
                    '{ "name": "STATEMENTS", "container": ["creditCard"] },' +
                    '{' +
                    '"name": "TRANSACTIONS",' +
                    '"containerAttributes": {' +
                        '"BANK": { "numberOfTransactionDays": 365 },' +
                        '"INVESTMENT": { "numberOfTransactionDays": 90 },' +
                        '"CREDITCARD": { "numberOfTransactionDays": 90 }' +
                    '},' +
                    '"container": ["bank", "investment", "creditCard"]' +
                    '},' +
                    '{' +
                    '"name": "BASIC_ACCOUNT_INFO",' +
                    '"container": ["bank", "investment", "creditCard"]' +
                    '}' +
                ']' +
                '}' +
            '],' +
            '"isAddedByUser": "true"' +
            '},' +
            '{' +
            '"PRIORITY": "SEARCH",' +
            '"id": 16441,' +
            '"name": "AS Financial Inst1",' +
            '"loginUrl": "http://64.14.28.129/dag/index.do",' +
            '"baseUrl": "http://64.14.28.129/dag/index.do",' +
            '"favicon": "https://yodlee-1.hs.llnwd.net/v1/FAVICON/FAV_16441.SVG",' +
            '"logo": "https://yodlee-1.hs.llnwd.net/v1/LOGO/LOGO_16441_1_2.SVG",' +
            '"status": "Supported",' +
            '"isConsentRequired": false,' +
            '"authType": "CREDENTIALS",' +
            '"languageISOCode": "EN",' +
            '"primaryLanguageISOCode": "EN",' +
            '"countryISOCode": "US",' +
            '"lastModified": "2022-06-22T10:33:00Z",' +
            '"forgetPasswordUrl": "http://64.14.28.129/dag/index.do",' +
            '"isAutoRefreshEnabled": true,' +
            '"capability": [' +
                '{ "name": "CHALLENGE_DEPOSIT_VERIFICATION", "container": ["bank"] }' +
            '],' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"attribute": [' +
                    '{' +
                    '"name": "ACCOUNT_DETAILS",' +
                    '"container": ["bank", "investment", "creditCard"]' +
                    '},' +
                    '{ "name": "STATEMENTS", "container": ["creditCard"] },' +
                    '{' +
                    '"name": "TRANSACTIONS",' +
                    '"containerAttributes": {' +
                        '"BANK": { "numberOfTransactionDays": 365 },' +
                        '"INVESTMENT": { "numberOfTransactionDays": 90 },' +
                        '"CREDITCARD": { "numberOfTransactionDays": 90 }' +
                    '},' +
                    '"container": ["bank", "investment", "creditCard"]' +
                    '},' +
                    '{' +
                    '"name": "BASIC_ACCOUNT_INFO",' +
                    '"container": ["bank", "investment", "creditCard"]' +
                    '}' +
                ']' +
                '}' +
            '],' +
            '"isAddedByUser": "true"' +
            '},' +
            '{' +
            '"PRIORITY": "SEARCH",' +
            '"id": 16441,' +
            '"name": "AS Financial Inst2",' +
            '"loginUrl": "http://64.14.28.129/dag/index.do",' +
            '"baseUrl": "http://64.14.28.129/dag/index.do",' +
            '"favicon": "https://yodlee-1.hs.llnwd.net/v1/FAVICON/FAV_16441.SVG",' +
            '"logo": "https://yodlee-1.hs.llnwd.net/v1/LOGO/LOGO_16441_1_2.SVG",' +
            '"status": "Supported",' +
            '"isConsentRequired": false,' +
            '"authType": "CREDENTIALS",' +
            '"languageISOCode": "EN",' +
            '"primaryLanguageISOCode": "EN",' +
            '"countryISOCode": "US",' +
            '"lastModified": "2022-06-22T10:33:00Z",' +
            '"forgetPasswordUrl": "http://64.14.28.129/dag/index.do",' +
            '"isAutoRefreshEnabled": true,' +
            '"capability": [' +
                '{ "name": "CHALLENGE_DEPOSIT_VERIFICATION", "container": ["bank"] }' +
            '],' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"attribute": [' +
                    '{' +
                    '"name": "ACCOUNT_DETAILS",' +
                    '"container": ["bank", "investment", "creditCard"]' +
                    '},' +
                    '{ "name": "STATEMENTS", "container": ["creditCard"] },' +
                    '{' +
                    '"name": "TRANSACTIONS",' +
                    '"containerAttributes": {' +
                        '"BANK": { "numberOfTransactionDays": 365 },' +
                        '"INVESTMENT": { "numberOfTransactionDays": 90 },' +
                        '"CREDITCARD": { "numberOfTransactionDays": 90 }' +
                    '},' +
                    '"container": ["bank", "investment", "creditCard"]' +
                    '},' +
                    '{' +
                    '"name": "BASIC_ACCOUNT_INFO",' +
                    '"container": ["bank", "investment", "creditCard"]' +
                    '}' +
                ']' +
                '}' +
            '],' +
            '"isAddedByUser": "true"' +
            '}' +
        ']' +
    '}';
    
    public static Final String FINANCIAL_INSTITUTIONS_TEST_JSON = '{' +
        '"provider": ' +
            '[' +
            '{' +
                '"PRIORITY": "SEARCH",' +
                '"id": 16441,' +
                '"name": "AS Financial Inst",' +
                '"loginUrl": "http://64.14.28.129/dag/index.do",' +
                '"baseUrl": "http://64.14.28.129/dag/index.do",' +
                '"favicon": "https://yodlee-1.hs.llnwd.net/v1/FAVICON/FAV_16441.SVG",' +
                '"logo": "https://yodlee-1.hs.llnwd.net/v1/LOGO/LOGO_16441_1_2.SVG"' +
            '},' +
            '{' +
                '"PRIORITY": "SEARCH",' +
                '"id": 16442,' +
                '"name": "AS Financial Inst1",' +
                '"loginUrl": "http://64.14.28.129/dag/index.do",' +
                '"baseUrl": "http://64.14.28.129/dag/index.do",' +
                '"favicon": "https://yodlee-1.hs.llnwd.net/v1/FAVICON/FAV_16441.SVG",' +
                '"logo": "https://yodlee-1.hs.llnwd.net/v1/LOGO/LOGO_16441_1_2.SVG"' +
            '},' +
            '{' +
                '"PRIORITY": "SEARCH",' +
                '"id": 16443,' +
                '"name": "AS Financial Inst2",' +
                '"loginUrl": "http://64.14.28.129/dag/index.do",' +
                '"baseUrl": "http://64.14.28.129/dag/index.do",' +
                '"favicon": "https://yodlee-1.hs.llnwd.net/v1/FAVICON/FAV_16441.SVG",' +
                '"logo": "https://yodlee-1.hs.llnwd.net/v1/LOGO/LOGO_16441_1_2.SVG"' +
            '},' +
            '{' +
                '"PRIORITY": "SEARCH",' +
                '"id": 16444,' +
                '"name": "AS Financial Inst3",' +
                '"loginUrl": "http://64.14.28.129/dag/index.do",' +
                '"baseUrl": "http://64.14.28.129/dag/index.do",' +
                '"favicon": "https://yodlee-1.hs.llnwd.net/v1/FAVICON/FAV_16441.SVG",' +
                '"logo": "https://yodlee-1.hs.llnwd.net/v1/LOGO/LOGO_16441_1_2.SVG"' +
            '}' +
        ']' +
    '}';

    public static Final String FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON = '{' +
        '"providerAccount": [' +
            '{' +
            '"id": 21769933,' +
            '"aggregationSource": "USER",' +
            '"providerId": 16441,' +
            '"isManual": false,' +
            '"createdDate": "2022-07-22T08:28:55Z",' +
            '"status": "SUCCESS",' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"additionalStatus": "AVAILABLE_DATA_RETRIEVED",' +
                '"updateEligibility": "ALLOW_UPDATE",' +
                '"lastUpdated": "2022-07-28T21:26:57Z",' +
                '"lastUpdateAttempt": "2022-07-28T21:26:57Z",' +
                '"nextUpdateScheduled": "2022-07-29T11:36:56Z"' +
                '}' +
            ']' +
            '},' +
            '{' +
            '"id": 21759841,' +
            '"aggregationSource": "USER",' +
            '"providerId": 16441,' +
            '"isManual": false,' +
            '"createdDate": "2022-07-20T09:21:44Z",' +
            '"status": "SUCCESS",' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"additionalStatus": "AVAILABLE_DATA_RETRIEVED",' +
                '"updateEligibility": "ALLOW_UPDATE",' +
                '"lastUpdated": "2022-07-28T23:44:27Z",' +
                '"lastUpdateAttempt": "2022-07-28T23:44:27Z",' +
                '"nextUpdateScheduled": "2022-07-29T19:45:42Z"' +
                '}' +
            ']' +
            '},' +
            '{' +
            '"id": 21759844,' +
            '"aggregationSource": "USER",' +
            '"providerId": 25789,' +
            '"isManual": false,' +
            '"createdDate": "2022-07-20T09:21:44Z",' +
            '"status": "FAILED",' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"additionalStatus": "AVAILABLE_DATA_RETRIEVED",' +
                '"updateEligibility": "ALLOW_UPDATE",' +
                '"lastUpdated": "2022-07-28T23:44:27Z",' +
                '"lastUpdateAttempt": "2022-07-28T23:44:27Z",' +
                '"nextUpdateScheduled": "2022-07-29T19:45:42Z"' +
                '}' +
            ']' +
            '}' +
        ']' +
    '}';
    
    public static Final String TRANSACTION_TEST_JSON = '{' +
        '"yodleeTransaction": [' +
            '{' +
            '"yodleeDate": "2022-07-31",' +
            '"type": null,' +
            '"transactionDate": null,' +
            '"TOTAL": null,' +
            '"subType": null,' +
            '"status": "POSTED",' +
            '"runningBalance": null,' +
            '"postDate": null,' +
            '"parentCategoryId": null,' +
            '"merchantType": null,' +
            '"merchant": null,' +
            '"memo": null,' +
            '"id": "11111111",' +
            '"highLevelCategoryId": null,' +
            '"detailCategoryId": null,' +
            '"description": null,' +
            '"container": null,' +
            '"checkNumber": null,' +
            '"categoryType": null,' +
            '"categoryId": null,' +
            '"category": null,' +
            '"baseType": "Credit",' +
            '"amount": { "yodleeCurrency": "USD", "amount": 550 },' +
            '"accountId": "12345678"' +
            '},' +
            '{' +
            '"yodleeDate": "2022-07-30",' +
            '"type": null,' +
            '"transactionDate": null,' +
            '"TOTAL": null,' +
            '"subType": null,' +
            '"status": "POSTED",' +
            '"runningBalance": null,' +
            '"postDate": null,' +
            '"parentCategoryId": null,' +
            '"merchantType": null,' +
            '"merchant": null,' +
            '"memo": null,' +
            '"id": "22222222",' +
            '"highLevelCategoryId": null,' +
            '"detailCategoryId": null,' +
            '"description": null,' +
            '"container": null,' +
            '"checkNumber": null,' +
            '"categoryType": null,' +
            '"categoryId": null,' +
            '"category": null,' +
            '"baseType": "Debit",' +
            '"amount": { "yodleeCurrency": "USD", "amount": 660 },' +
            '"accountId": "12345678"' +
            '},' +
            '{' +
            '"yodleeDate": "2022-07-30",' +
            '"type": null,' +
            '"transactionDate": null,' +
            '"TOTAL": null,' +
            '"subType": null,' +
            '"status": "POSTED",' +
            '"runningBalance": null,' +
            '"postDate": null,' +
            '"parentCategoryId": null,' +
            '"merchantType": null,' +
            '"merchant": null,' +
            '"memo": null,' +
            '"id": "33333333",' +
            '"highLevelCategoryId": null,' +
            '"detailCategoryId": null,' +
            '"description": null,' +
            '"container": null,' +
            '"checkNumber": null,' +
            '"categoryType": null,' +
            '"categoryId": null,' +
            '"category": null,' +
            '"baseType": "Mastercard",' +
            '"amount": { "yodleeCurrency": "USD", "amount": 660 },' +
            '"accountId": "123456789001"' +
            '},' +
            '{' +
            '"yodleeDate": "2022-07-30",' +
            '"type": null,' +
            '"transactionDate": null,' +
            '"TOTAL": null,' +
            '"subType": null,' +
            '"status": "POSTED",' +
            '"runningBalance": null,' +
            '"postDate": null,' +
            '"parentCategoryId": null,' +
            '"merchantType": null,' +
            '"merchant": null,' +
            '"memo": null,' +
            '"id": "44444444",' +
            '"highLevelCategoryId": null,' +
            '"detailCategoryId": null,' +
            '"description": null,' +
            '"container": null,' +
            '"checkNumber": null,' +
            '"categoryType": null,' +
            '"categoryId": null,' +
            '"category": null,' +
            '"baseType": "platinum",' +
            '"amount": { "yodleeCurrency": "USD", "amount": 660 },' +
            '"accountId": "123456789"' +
            '},' +
            '{' +
            '"yodleeDate": "2022-07-30",' +
            '"type": null,' +
            '"transactionDate": null,' +
            '"TOTAL": null,' +
            '"subType": null,' +
            '"status": "POSTED",' +
            '"runningBalance": null,' +
            '"postDate": null,' +
            '"parentCategoryId": null,' +
            '"merchantType": null,' +
            '"merchant": null,' +
            '"memo": null,' +
            '"id": "55555555",' +
            '"highLevelCategoryId": null,' +
            '"detailCategoryId": null,' +
            '"description": null,' +
            '"container": null,' +
            '"checkNumber": null,' +
            '"categoryType": null,' +
            '"categoryId": null,' +
            '"category": null,' +
            '"baseType": "platinum",' +
            '"amount": { "yodleeCurrency": "USD", "amount": 550 },' +
            '"accountId": "123456789"' +
            '}' +
        ']' +
    '}';

    public static Final String ACCOUNT_TEST_JSON = '{' +
        '"account": [' +
            '{' +
            '"CONTAINER": "bank",' +
            '"providerAccountId": 21769933,' +
            '"accountName": "Dag Checking Account",' +
            '"accountStatus": "ACTIVE",' +
            '"accountNumber": "2345",' +
            '"aggregationSource": "USER",' +
            '"isAsset": true,' +
            '"balance": { "currency": "USD", "amount": 1600.0 },' +
            '"id": 29475986,' +
            '"includeInNetWorth": true,' +
            '"providerId": "16441",' +
            '"providerName": "Dag Site",' +
            '"isManual": false,' +
            '"availableBalance": { "currency": "USD", "amount": 1500.0 },' +
            '"currentBalance": { "currency": "USD", "amount": 1600.0 },' +
            '"accountType": "CHECKING",' +
            '"displayedName": "Robin",' +
            '"createdDate": "2022-07-22T08:28:58Z",' +
            '"classification": "PERSONAL",' +
            '"interestRate": 0.01,' +
            '"lastUpdated": "2022-07-27T18:54:19Z",' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"additionalStatus": "AVAILABLE_DATA_RETRIEVED",' +
                '"updateEligibility": "ALLOW_UPDATE",' +
                '"lastUpdated": "2022-07-27T18:54:19Z",' +
                '"lastUpdateAttempt": "2022-07-27T18:54:19Z",' +
                '"nextUpdateScheduled": "2022-07-28T21:24:19Z"' +
                '}' +
            '],' +
            '"autoRefresh": {' +
                '"status": "ENABLED",' +
                '"additionalStatus": "SCHEDULED",' +
                '"asOfDate": "2022-07-22T08:28:59Z"' +
            '}' +
            '},' +
            '{' +
            '"CONTAINER": "bank",' +
            '"providerAccountId": 21759841,' +
            '"accountName": "Dag Saving Plus",' +
            '"accountStatus": "ACTIVE",' +
            '"accountNumber": "4197",' +
            '"aggregationSource": "USER",' +
            '"isAsset": true,' +
            '"balance": { "currency": "USD", "amount": 305.0 },' +
            '"id": 29462280,' +
            '"includeInNetWorth": true,' +
            '"providerId": "16441",' +
            '"providerName": "Dag Site",' +
            '"isManual": false,' +
            '"availableBalance": { "currency": "USD", "amount": 105.0 },' +
            '"currentBalance": { "currency": "USD", "amount": 305.0 },' +
            '"accountType": "SAVINGS",' +
            '"displayedName": "Robin",' +
            '"createdDate": "2022-07-20T09:21:46Z",' +
            '"classification": "PERSONAL",' +
            '"lastUpdated": "2022-07-27T17:19:39Z",' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"additionalStatus": "AVAILABLE_DATA_RETRIEVED",' +
                '"updateEligibility": "ALLOW_UPDATE",' +
                '"lastUpdated": "2022-07-27T17:19:40Z",' +
                '"lastUpdateAttempt": "2022-07-27T17:19:40Z",' +
                '"nextUpdateScheduled": "2022-07-29T01:09:34Z"' +
                '}' +
            '],' +
            '"autoRefresh": {' +
                '"status": "ENABLED",' +
                '"additionalStatus": "SCHEDULED",' +
                '"asOfDate": "2022-07-20T09:21:47Z"' +
            '}' +
            '},' +
            '{' +
            '"CONTAINER": "bank",' +
            '"providerAccountId": 21759841,' +
            '"accountName": "Dag Fixed Term Deposit",' +
            '"accountStatus": "ACTIVE",' +
            '"accountNumber": "88108044789881",' +
            '"aggregationSource": "USER",' +
            '"isAsset": true,' +
            '"balance": { "currency": "USD", "amount": 27517.34 },' +
            '"id": 29462279,' +
            '"includeInNetWorth": true,' +
            '"providerId": "16441",' +
            '"providerName": "Dag Site",' +
            '"isManual": false,' +
            '"currentBalance": { "currency": "USD", "amount": 27517.34 },' +
            '"accountType": "CD",' +
            '"displayedName": "Robin",' +
            '"createdDate": "2022-07-20T09:21:46Z",' +
            '"classification": "PERSONAL",' +
            '"interestRate": 0.01,' +
            '"lastUpdated": "2022-07-27T17:19:39Z",' +
            '"maturityAmount": { "currency": "USD", "amount": 36000.0 },' +
            '"maturityDate": "2021-05-03",' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"additionalStatus": "AVAILABLE_DATA_RETRIEVED",' +
                '"updateEligibility": "ALLOW_UPDATE",' +
                '"lastUpdated": "2022-07-27T17:19:40Z",' +
                '"lastUpdateAttempt": "2022-07-27T17:19:40Z",' +
                '"nextUpdateScheduled": "2022-07-29T01:09:34Z"' +
                '}' +
            '],' +
            '"autoRefresh": {' +
                '"status": "ENABLED",' +
                '"additionalStatus": "SCHEDULED",' +
                '"asOfDate": "2022-07-20T09:21:47Z"' +
            '}' +
            '},' +
            '{' +
            '"CONTAINER": "bank",' +
            '"providerAccountId": 21759841,' +
            '"accountName": "Dag Checking Account",' +
            '"accountStatus": "ACTIVE",' +
            '"accountNumber": "2345",' +
            '"aggregationSource": "USER",' +
            '"isAsset": true,' +
            '"balance": { "currency": "USD", "amount": 1600.0 },' +
            '"id": 29462278,' +
            '"includeInNetWorth": true,' +
            '"providerId": "16441",' +
            '"providerName": "Dag Site",' +
            '"isManual": false,' +
            '"availableBalance": { "currency": "USD", "amount": 1500.0 },' +
            '"currentBalance": { "currency": "USD", "amount": 1600.0 },' +
            '"accountType": "CHECKING",' +
            '"displayedName": "Robin",' +
            '"createdDate": "2022-07-20T09:21:46Z",' +
            '"classification": "PERSONAL",' +
            '"interestRate": 0.01,' +
            '"lastUpdated": "2022-07-27T17:19:39Z",' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"additionalStatus": "AVAILABLE_DATA_RETRIEVED",' +
                '"updateEligibility": "ALLOW_UPDATE",' +
                '"lastUpdated": "2022-07-27T17:19:40Z",' +
                '"lastUpdateAttempt": "2022-07-27T17:19:40Z",' +
                '"nextUpdateScheduled": "2022-07-29T01:09:34Z"' +
                '}' +
            '],' +
            '"autoRefresh": {' +
                '"status": "ENABLED",' +
                '"additionalStatus": "SCHEDULED",' +
                '"asOfDate": "2022-07-20T09:21:47Z"' +
            '}' +
            '}' +
        ']' +
    '}';

    
    public Static Final String BAD_REQUEST = 'Bad Request';
    
    public static Final String FINANCIAL_INSTITUTIONS_IDENTITITES_STATUS_FAILED_TEST_JSON = '{' +
        '"providerAccount": [' +
            '{' +
            '"id": 21769933,' +
            '"aggregationSource": "USER",' +
            '"providerId": 16441,' +
            '"isManual": false,' +
            '"createdDate": "2022-07-22T08:28:55Z",' +
            '"status": "FAILED",' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"additionalStatus": "AVAILABLE_DATA_RETRIEVED",' +
                '"updateEligibility": "ALLOW_UPDATE",' +
                '"lastUpdated": "2022-07-28T21:26:57Z",' +
                '"lastUpdateAttempt": "2022-07-28T21:26:57Z",' +
                '"nextUpdateScheduled": "2022-07-29T11:36:56Z"' +
                '}' +
            ']' +
            '},' +
            '{' +
            '"id": 21759841,' +
            '"aggregationSource": "USER",' +
            '"providerId": 16441,' +
            '"isManual": false,' +
            '"createdDate": "2022-07-20T09:21:44Z",' +
            '"status": "SUCCESS",' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"additionalStatus": "AVAILABLE_DATA_RETRIEVED",' +
                '"updateEligibility": "ALLOW_UPDATE",' +
                '"lastUpdated": "2022-07-28T23:44:27Z",' +
                '"lastUpdateAttempt": "2022-07-28T23:44:27Z",' +
                '"nextUpdateScheduled": "2022-07-29T19:45:42Z"' +
                '}' +
            ']' +
            '}' +
        ']' +
    '}';

    public static Final String FINANCIAL_INSTITUTIONS_TEST_JSON1 = '{' +
        '"provider": ' +
            '[' +
            '{' +
                '"PRIORITY": "SEARCH",' +
                '"id": 16441,' +
                '"name": "AS Financial Inst",' +
                '"loginUrl": "http://64.14.28.129/dag/index.do",' +
                '"baseUrl": "http://64.14.28.129/dag/index.do",' +
                '"favicon": "https://yodlee-1.hs.llnwd.net/v1/FAVICON/FAV_16441.SVG",' +
                '"logo": "https://yodlee-1.hs.llnwd.net/v1/LOGO/LOGO_16441_1_2.SVG"' +
            '}' +
        ']' +
    '}';

    public static Final String FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON1 = '{' +
        '"providerAccount": [' +
            '{' +
            '"id": 21769933,' +
            '"aggregationSource": "USER",' +
            '"providerId": 16441,' +
            '"isManual": false,' +
            '"createdDate": "2022-07-22T08:28:55Z",' +
            '"status": "SUCCESS",' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"additionalStatus": "AVAILABLE_DATA_RETRIEVED",' +
                '"updateEligibility": "ALLOW_UPDATE",' +
                '"lastUpdated": "2022-07-28T21:26:57Z",' +
                '"lastUpdateAttempt": "2022-07-28T21:26:57Z",' +
                '"nextUpdateScheduled": "2022-07-29T11:36:56Z"' +
                '}' +
            ']' +
            '},' +
            
            '{' +
            '"id": 21759841,' +
            '"aggregationSource": "USER",' +
            '"providerId": 16441,' +
            '"isManual": false,' +
            '"createdDate": "2022-07-20T09:21:44Z",' +
            '"status": "SUCCESS",' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"additionalStatus": "AVAILABLE_DATA_RETRIEVED",' +
                '"updateEligibility": "ALLOW_UPDATE",' +
                '"lastUpdated": "2022-07-28T23:44:27Z",' +
                '"lastUpdateAttempt": "2022-07-28T23:44:27Z",' +
                '"nextUpdateScheduled": "2022-07-29T19:45:42Z"' +
                '}' +
            ']' +
            '}' +
        ']' +
    '}';

    public static Final String FINANCIAL_INSTITUTIONS_IDENTITITES_TEST_JSON_MISSING_FI = '{' +
        '"providerAccount": [' +
            '{' +
            '"id": 21769933,' +
            '"aggregationSource": "USER",' +
            '"providerId": 55555,' +
            '"isManual": false,' +
            '"createdDate": "2022-07-22T08:28:55Z",' +
            '"status": "SUCCESS",' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"additionalStatus": "AVAILABLE_DATA_RETRIEVED",' +
                '"updateEligibility": "ALLOW_UPDATE",' +
                '"lastUpdated": "2022-07-28T21:26:57Z",' +
                '"lastUpdateAttempt": "2022-07-28T21:26:57Z",' +
                '"nextUpdateScheduled": "2022-07-29T11:36:56Z"' +
                '}' +
            ']' +
            '},' +
            
            '{' +
            '"id": 21759841,' +
            '"aggregationSource": "USER",' +
            '"providerId": 55555,' +
            '"isManual": false,' +
            '"createdDate": "2022-07-20T09:21:44Z",' +
            '"status": "SUCCESS",' +
            '"dataset": [' +
                '{' +
                '"name": "BASIC_AGG_DATA",' +
                '"additionalStatus": "AVAILABLE_DATA_RETRIEVED",' +
                '"updateEligibility": "ALLOW_UPDATE",' +
                '"lastUpdated": "2022-07-28T23:44:27Z",' +
                '"lastUpdateAttempt": "2022-07-28T23:44:27Z",' +
                '"nextUpdateScheduled": "2022-07-29T19:45:42Z"' +
                '}' +
            ']' +
            '}' +
        ']' +
    '}';
}