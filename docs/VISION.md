# Reference app for contact tracing
----
Current solutions for contact tracing involve the publication of standalone apps. Such apps must solve both technical and deployment challenges. The intense focus on deployment can result in a slew of duplicated efforts and incompatible data standards.

We propose a collaborative effort focused on the technical challenges. This effort will result in a well-tested, modular reference architecture and implementation. App builders can then focus on locally relevant design, incentives and partnerships.

The relevant modules include:
1. location tracking: using the open source [e-mission][https://github.com/e-mission/] platform
1. BLE contact event exchange: using the open source [covid-watch](https://github.com/covid19risk] platform
1. (potentially) BLE contact event exchange: using the SG app code if/when it is open sourced
1. public exposure database: using the complementary [public COVID19 database](https://github.com/covid19database/covid19db-api)
1. (potentially) pairwise risk estimation on the phone: using the [private kit](https://github.com/tripleblindmarket/private-kit) project
1. (potentially) pairwise risk estimation on the server: using the [SafeTrace](https://github.com/enigmampc/SafeTrace) project

### Our focus: collaboration, not competition

We are not building an app. We are building shared infrastructure that other apps can use. Our app is essentially a showcase and a test vehicle to ensure that the shared infrastructure works. We are not sure if we will even release it in the stores. Other projects are doing a great job of building delightful apps that provide high customer value. We don't want to compete with them. We want to focus on enabling collaborations between the various projects, so that we can tackle this global crisis together.

### Implmentation strategy

Our implementation strategy has three main components.
- Modularization: We will contribute PRs to the projects listed above to modularize their code
- Integration: We will then integrate the modules in our reference app and ensure that they work together
- Standardization: We will ensure that the modules generate standard data formats which will encourage interoperability

The virus does not respect boundaries. Such interoperability can help us create shared or federated databases to track COVID-19 cases across jurisdictions. It might also encourage organizations who are already collecting such data to share it with appropriate consent. See our companion project for more details.

### Contributing

Since we don't plan to release our app to a wide audience, we do not have an immediate need for UX designers or front-end developers. Our most immediate need is for:
- app developers who can work with background operations in native code
- software engineers who are familiar with pulling out code into modules and can create interfaces for a wide variety of native plugins (cordova/react native/capacitor/flutter)
- build engineers to help with the tooling that keeps the interfaces compatible

### Why you?

We built a modular, extensible smartphone-based app platform (https://github.com/e-mission/) which we will actually re-use here. We are also building a [common backend data service](https://github.com/covid19database/covid19db-api) that we will be integrating with.
