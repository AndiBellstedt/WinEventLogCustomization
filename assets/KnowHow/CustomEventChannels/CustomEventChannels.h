//**********************************************************************`
//* This is an include file generated by Message Compiler.             *`
//*                                                                    *`
//* Copyright (c) Microsoft Corporation. All Rights Reserved.          *`
//**********************************************************************`
#pragma once
//+
// Provider Corp-WEC-Basic Event Count 0
//+
EXTERN_C __declspec(selectany) const GUID WEC_EVENTS_Basic = {0xcf27f07f, 0x7013, 0x483a, {0xbc, 0x74, 0x97, 0xa0, 0xf6, 0xaa, 0x32, 0xfc}};

//
// Channel
//
#define WEC_Basic_Domain_Controllers 0x10
#define WEC_Basic_Member_Servers 0x11
#define WEC_Basic_Privileged_Access_Workstations 0x12
#define WEC_Basic_Clients 0x13
#define WEC_Basic_Critical 0x14
#define WEC_Basic_Security 0x15
#define WEC_Basic_PowerShell 0x16
#define WEC_Basic_Application 0x17

//
// Event Descriptors
//
//+
// Provider Corp-WEC-Advanced Event Count 0
//+
EXTERN_C __declspec(selectany) const GUID WEC_EVENTS_Advanced = {0x0014355c, 0xd05c, 0x4b81, {0x9c, 0x93, 0x1f, 0x6a, 0x39, 0x07, 0xe5, 0x35}};

//
// Channel
//
#define WEC_Advanced_Domain_Controllers 0x10
#define WEC_Advanced_Member_Servers 0x11
#define WEC_Advanced_Privileged_Access_Workstations 0x12
#define WEC_Advanced_Clients 0x13
#define WEC_Advanced_Critical 0x14
#define WEC_Advanced_Security 0x15
#define WEC_Advanced_PowerShell 0x16
#define WEC_Advanced_Application 0x17

//
// Event Descriptors
//
