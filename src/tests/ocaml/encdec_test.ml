(************************* CeCILL-B HEADER ************************************
    Copyright ANSSI (2014)
    Contributors : Ryad BENADJILA [ryad.benadjila@ssi.gouv.fr] and
    Thomas CALDERON [thomas.calderon@ssi.gouv.fr] and Marion
    DAUBIGNARD [marion.daubignard@ssi.gouv.fr]

    This software is a computer program whose purpose is to implement
    a PKCS#11 proxy as well as a PKCS#11 filter with security features
    in mind. The project source tree is subdivided in six parts.
    There are five main parts:
      1] OCaml/C PKCS#11 bindings (using OCaml IDL).
      2] XDR RPC generators (to be used with ocamlrpcgen and/or rpcgen).
      3] A PKCS#11 RPC server (daemon) in OCaml using a Netplex RPC basis.
      4] A PKCS#11 filtering module used as a backend to the RPC server.
      5] A PKCS#11 client module that comes as a dynamic library offering
         the PKCS#11 API to the software.
    There is one "optional" part:
      6] Tests in C and OCaml to be used with client module 5] or with the
         bindings 1]

    Here is a big picture of how the PKCS#11 proxy works:

 ----------------------   --------  socket (TCP or Unix)  --------------------
| 3] PKCS#11 RPC server|-|2] RPC  |<+++++++++++++++++++> | 5] Client library  |
 ----------------------  |  Layer | [SSL/TLS optional]   |  --------          |
           |              --------                       | |2] RPC  | PKCS#11 |
 ----------------------                                  | |  Layer |functions|
| 4] PKCS#11 filter    |                                 |  --------          |
 ----------------------                                   --------------------
           |                                                        |
 ----------------------                                             |
| 1] PKCS#11 OCaml     |                                  { PKCS#11 INTERFACE }
|       bindings       |                                            |
 ----------------------                                       APPLICATION
           |
           |
 { PKCS#11 INTERFACE }
           |
 REAL PKCS#11 MIDDLEWARE
    (shared library)

    This software is governed by the CeCILL-B license under French law and
    abiding by the rules of distribution of free software.  You can  use,
    modify and/ or redistribute the software under the terms of the CeCILL-B
    license as circulated by CEA, CNRS and INRIA at the following URL
    "http://www.cecill.info".

    As a counterpart to the access to the source code and  rights to copy,
    modify and redistribute granted by the license, users are provided only
    with a limited warranty  and the software's author,  the holder of the
    economic rights,  and the successive licensors  have only  limited
    liability.

    In this respect, the user's attention is drawn to the risks associated
    with loading,  using,  modifying and/or developing or reproducing the
    software by the user in light of its specific status of free software,
    that may mean  that it is complicated to manipulate,  and  that  also
    therefore means  that it is reserved for developers  and  experienced
    professionals having in-depth computer knowledge. Users are therefore
    encouraged to load and test the software's suitability as regards their
    requirements in conditions enabling the security of their systems and/or
    data to be ensured and,  more generally, to use and operate it in the
    same conditions as regards security.

    The fact that you are presently reading this means that you have had
    knowledge of the CeCILL-B license and that you accept its terms.

    The current source code is part of the tests 6] source tree.

    Project: PKCS#11 Filtering Proxy
    File:    src/tests/ocaml/encdec_test.ml

************************** CeCILL-B HEADER ***********************************)
open Printf
open P11_common

let encrypt_decrypt_some_data_with_mech_type session pubkey_ privkey_ data mech_type = 
    let enc_mech = { Pkcs11.mechanism = mech_type ; Pkcs11.parameter = [| |] } in
    printf "--------------\n";
    printf "%s encrypt/decrypt\n" (Pkcs11.match_cKM_value mech_type);
    let enc_data_ = encrypt_some_data session enc_mech pubkey_ data in
    printf "\tthrough Encrypt single call is:\n";
    Pkcs11.print_hex_array enc_data_;
    let dec_data_ = decrypt_some_data session enc_mech privkey_ enc_data_ in
    printf "\tthrough Decrypt single call is:\n";
    Printf.printf "'%s'\n" (Pkcs11.char_array_to_string dec_data_)

let _ = 
    let _ = init_module in
    let conf_user_pin = fetch_pin in
    (* Initialize module *)
    let ret_value = Pkcs11.mL_CK_C_Initialize () in
    let _ = check_ret ret_value C_InitializeError false in
    printf "C_Initialize ret: %s\n" (Pkcs11.match_cKR_value ret_value);

    (* Fetch slot count by passing 0n (present) 0n (count) *)
    let (ret_value, slot_list_, count) = Pkcs11.mL_CK_C_GetSlotList 0n 0n in
    let _ = check_ret ret_value C_GetSlotListError false in
    printf "C_GetSlotList ret: %s, Count = %s, slot_list =" (Nativeint.to_string ret_value) (Nativeint.to_string count);

    Pkcs11.print_int_array slot_list_;

    (* Fetch slot list by passing 0n count *)
    let (ret_value, slot_list_, count) = Pkcs11.mL_CK_C_GetSlotList 0n count in
    let _ = check_ret ret_value C_GetSlotListError false in
    printf "C_GetSlotList ret: %s, Count = %s, slot_list =" (Nativeint.to_string ret_value) (Nativeint.to_string count);
    Pkcs11.print_int_array slot_list_;

    Array.iter print_slots slot_list_;

    (* hardcoded take first available slot *)
    let slot_id = slot_list_.(0) in

    (* GetMechList *)
    let mechanism_list_ = get_mechanism_list_for_slot slot_id in

    let mechanisms = Array.map Pkcs11.match_cKM_value mechanism_list_ in
    Pkcs11.print_string_array mechanisms;

    (* OpenSession and Login *)
    let (ret_value, session) = Pkcs11.mL_CK_C_OpenSession slot_id (Nativeint.logor Pkcs11.cKF_SERIAL_SESSION Pkcs11.cKF_RW_SESSION) in
    let _ = check_ret ret_value C_OpenSessionError false in
    printf "C_OpenSession ret: %s\n" (Pkcs11.match_cKR_value ret_value);
    let user_pin = Pkcs11.string_to_char_array conf_user_pin in
    let ret_value = Pkcs11.mL_CK_C_Login session Pkcs11.cKU_USER user_pin in
    let _ = check_ret ret_value C_LoginError false in
    printf "C_Login ret: %s\n" (Pkcs11.match_cKR_value ret_value);

    while true do

    begin
        (* Use higher level function to generate RSA template and create keypair *)
        let (pub_template_, priv_template_) = generate_rsa_template 1024n (Some "mytest") (Some "1234") in
        let (pubkey_, privkey_) = generate_rsa_key_pair session 1024n pub_template_ priv_template_ in

        let enc_to_test = ["CKM_RSA_PKCS" ] in

        let enc_to_test = List.map Pkcs11.string_to_cKM_value enc_to_test in
        let mech_intersect = intersect enc_to_test (Array.to_list mechanism_list_) in

        let _ = List.map (encrypt_decrypt_some_data_with_mech_type session pubkey_ privkey_ "mysecretdata") mech_intersect in

        (* Destroy All objects *)
        let _ = List.map (destroy_some_object session) [privkey_; pubkey_] in

        flush stdout;
        Gc.full_major()
    end
    done;
    (* Logout and finalize *)
    let ret_value = Pkcs11.mL_CK_C_Logout session in
    printf "C_Logout ret: %s\n" (Pkcs11.match_cKR_value ret_value);
    let _ = check_ret ret_value C_LogoutError false in
    let ret_value = Pkcs11.mL_CK_C_CloseSession session in
    let _ = check_ret ret_value C_CloseSessionError false in
    printf "C_CloseSession ret: %s\n" (Pkcs11.match_cKR_value ret_value);

    let ret_value = Pkcs11.mL_CK_C_Finalize () in
    let _ = check_ret ret_value C_FinalizeError false in
    printf "C_Finalize ret: %s\n" (Pkcs11.match_cKR_value ret_value)
