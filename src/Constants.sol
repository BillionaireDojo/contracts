// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Constants {
    string[6] names = ["Jeff Bezos", "Tim Cook","Jack Dorsey","Elon Musk","Sundar Pichai","Mark Zuckerberg"];
    string[6] punchlines = [
        "Let's out these pussies faster than an Amazon Prime delivery, kid!",
        "Let's make sure these pussies won't be able to use a Vision Pro, kid!",
        "Let's turn these pussies into Bitcoin mining gear, kid!",
        "Let's kick these pussies out of the solar system, kid!",
        "Let's show these pussies what 'Be Evil' really means, kid!",
        "Let's freakin' ZUCK these pussies, kid!"
    ];
    string[6] imgUrls = [
        "https://arweave.net/gt-i_PhFWQg7MeDOpLRbtPgqpO7U66aPTxUKa96-F90",
        "https://arweave.net/Bu_v2sLZkgLQ0NwAIAk4pCzF2kkf6AT1rhRcrGjyBLU",
        "https://arweave.net/kyCI_G7v_7wrpgItfqgAdfLksczW2px-v7ifPY_Z95Q",
        "https://arweave.net/Zoo-AkALSEJqjgioGLMwZrO_UKekGFHCdXMBSt0COV4",
        "https://arweave.net/AmvWrzj1nKxnHsr4jXkwXfete8037VZjx268r04n44U",
        "https://arweave.net/QfWj433bGOIsO3SQVMN3L5-WTgYZkgjx5N7C7m28h-Y"
    ];

    function _setPunchlines(string[6] memory _punchlines) internal {
        punchlines = _punchlines;
    }

    function _setImgUrls(string[6] memory _imgUrls) internal {
        imgUrls = _imgUrls;
    }
}