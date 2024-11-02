/*
   Copyright 2018 Lip Wee Yeo Amano

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

/** libkeccak-tiny
*
* A single-file implementation of SHA-3 and SHAKE.
*
* Modified for openCL processing by lwYeo
* Date: August, 2018
*
* Implementor: David Leon Gil
* License: CC0, attribution kindly requested. Blame taken too,
* but not liability.
*/

/*
  Copied from https://github.com/lwYeo/SoliditySHA3Miner/blob/9737b16d3c3565702292c13b22cf06dd9b8f99ae/SoliditySHA3Miner/Miner/Kernels/OpenCL/sha3KingKernel.cl,
  with irrelevant definitions removed, yet with no present chunks altered, by kayabaNerve
*/

/******** The Keccak-f[1600] permutation ********/

#define OPENCL_PLATFORM_UNKNOWN	0
#define OPENCL_PLATFORM_AMD		2

#ifndef PLATFORM
#	define PLATFORM				OPENCL_PLATFORM_UNKNOWN
#endif

#if PLATFORM == OPENCL_PLATFORM_AMD
#	pragma OPENCL EXTENSION		cl_amd_media_ops : enable
#endif

static inline ulong rol(const ulong x, const uint s)
{
#if PLATFORM == OPENCL_PLATFORM_AMD

	uint2 output;
	uint2 x2 = as_uint2(x);

	output = (s > 32u) ? amd_bitalign((x2).yx, (x2).xy, 64u - s) : amd_bitalign((x2).xy, (x2).yx, 32u - s);
	return as_ulong(output);

#else

	return (((x) << s) | ((x) >> (64u - s)));

#endif
}

/*** Constants. ***/
__constant static ulong const Keccak_f1600_RC[24] =
{
	0x0000000000000001, 0x0000000000008082, 0x800000000000808a,
	0x8000000080008000, 0x000000000000808b, 0x0000000080000001,
	0x8000000080008081, 0x8000000000008009, 0x000000000000008a,
	0x0000000000000088, 0x0000000080008009, 0x000000008000000a,
	0x000000008000808b, 0x800000000000008b, 0x8000000000008089,
	0x8000000000008003, 0x8000000000008002, 0x8000000000000080,
	0x000000000000800a, 0x800000008000000a, 0x8000000080008081,
	0x8000000000008080, 0x0000000080000001, 0x8000000080008008
};

__constant static const uchar rho[24] =
{
	1, 3, 6, 10, 15, 21,
	28, 36, 45, 55, 2, 14,
	27, 41, 56, 8, 25, 43,
	62, 18, 39, 61, 20, 44
};

__constant static const uchar pi[24] =
{
	10, 7, 11, 17, 18, 3,
	5, 16, 8, 21, 24, 4,
	15, 23, 19, 13, 12, 2,
	20, 14, 22, 9, 6, 1
};

/*** This is the unrolled version of the original macro ***/
static inline void keccakf(void *state)
{
	ulong *a = (ulong *)state;
	ulong b[5] = { 0, 0, 0, 0, 0 };
	ulong t;

#	pragma unroll
	for (uint i = 0; i < 24u; ++i)
	{
		// Theta
		b[0] = a[0] ^ a[5] ^ a[10] ^ a[15] ^ a[20];
		b[1] = a[1] ^ a[6] ^ a[11] ^ a[16] ^ a[21];
		b[2] = a[2] ^ a[7] ^ a[12] ^ a[17] ^ a[22];
		b[3] = a[3] ^ a[8] ^ a[13] ^ a[18] ^ a[23];
		b[4] = a[4] ^ a[9] ^ a[14] ^ a[19] ^ a[24];

		a[0] ^= b[4] ^ rol(b[1], 1);
		a[5] ^= b[4] ^ rol(b[1], 1);
		a[10] ^= b[4] ^ rol(b[1], 1);
		a[15] ^= b[4] ^ rol(b[1], 1);
		a[20] ^= b[4] ^ rol(b[1], 1);

		a[1] ^= b[0] ^ rol(b[2], 1);
		a[6] ^= b[0] ^ rol(b[2], 1);
		a[11] ^= b[0] ^ rol(b[2], 1);
		a[16] ^= b[0] ^ rol(b[2], 1);
		a[21] ^= b[0] ^ rol(b[2], 1);

		a[2] ^= b[1] ^ rol(b[3], 1);
		a[7] ^= b[1] ^ rol(b[3], 1);
		a[12] ^= b[1] ^ rol(b[3], 1);
		a[17] ^= b[1] ^ rol(b[3], 1);
		a[22] ^= b[1] ^ rol(b[3], 1);

		a[3] ^= b[2] ^ rol(b[4], 1);
		a[8] ^= b[2] ^ rol(b[4], 1);
		a[13] ^= b[2] ^ rol(b[4], 1);
		a[18] ^= b[2] ^ rol(b[4], 1);
		a[23] ^= b[2] ^ rol(b[4], 1);

		a[4] ^= b[3] ^ rol(b[0], 1);
		a[9] ^= b[3] ^ rol(b[0], 1);
		a[14] ^= b[3] ^ rol(b[0], 1);
		a[19] ^= b[3] ^ rol(b[0], 1);
		a[24] ^= b[3] ^ rol(b[0], 1);

		// Rho Pi
		t = a[1];
		b[0] = a[pi[0]];
		a[pi[0]] = rol(t, rho[0]);

		t = b[0];
		b[0] = a[pi[1]];
		a[pi[1]] = rol(t, rho[1]);

		t = b[0];
		b[0] = a[pi[2]];
		a[pi[2]] = rol(t, rho[2]);

		t = b[0];
		b[0] = a[pi[3]];
		a[pi[3]] = rol(t, rho[3]);

		t = b[0];
		b[0] = a[pi[4]];
		a[pi[4]] = rol(t, rho[4]);

		t = b[0];
		b[0] = a[pi[5]];
		a[pi[5]] = rol(t, rho[5]);

		t = b[0];
		b[0] = a[pi[6]];
		a[pi[6]] = rol(t, rho[6]);

		t = b[0];
		b[0] = a[pi[7]];
		a[pi[7]] = rol(t, rho[7]);

		t = b[0];
		b[0] = a[pi[8]];
		a[pi[8]] = rol(t, rho[8]);

		t = b[0];
		b[0] = a[pi[9]];
		a[pi[9]] = rol(t, rho[9]);

		t = b[0];
		b[0] = a[pi[10]];
		a[pi[10]] = rol(t, rho[10]);

		t = b[0];
		b[0] = a[pi[11]];
		a[pi[11]] = rol(t, rho[11]);

		t = b[0];
		b[0] = a[pi[12]];
		a[pi[12]] = rol(t, rho[12]);

		t = b[0];
		b[0] = a[pi[13]];
		a[pi[13]] = rol(t, rho[13]);

		t = b[0];
		b[0] = a[pi[14]];
		a[pi[14]] = rol(t, rho[14]);

		t = b[0];
		b[0] = a[pi[15]];
		a[pi[15]] = rol(t, rho[15]);

		t = b[0];
		b[0] = a[pi[16]];
		a[pi[16]] = rol(t, rho[16]);

		t = b[0];
		b[0] = a[pi[17]];
		a[pi[17]] = rol(t, rho[17]);

		t = b[0];
		b[0] = a[pi[18]];
		a[pi[18]] = rol(t, rho[18]);

		t = b[0];
		b[0] = a[pi[19]];
		a[pi[19]] = rol(t, rho[19]);

		t = b[0];
		b[0] = a[pi[20]];
		a[pi[20]] = rol(t, rho[20]);

		t = b[0];
		b[0] = a[pi[21]];
		a[pi[21]] = rol(t, rho[21]);

		t = b[0];
		b[0] = a[pi[22]];
		a[pi[22]] = rol(t, rho[22]);

		t = b[0];
		b[0] = a[pi[23]];
		a[pi[23]] = rol(t, rho[23]);

		// Chi
		b[0] = a[0];
		b[1] = a[1];
		b[2] = a[2];
		b[3] = a[3];
		b[4] = a[4];
		a[0] = b[0] ^ ((~b[1]) & b[2]);
		a[1] = b[1] ^ ((~b[2]) & b[3]);
		a[2] = b[2] ^ ((~b[3]) & b[4]);
		a[3] = b[3] ^ ((~b[4]) & b[0]);
		a[4] = b[4] ^ ((~b[0]) & b[1]);

		b[0] = a[5];
		b[1] = a[6];
		b[2] = a[7];
		b[3] = a[8];
		b[4] = a[9];
		a[5] = b[0] ^ ((~b[1]) & b[2]);
		a[6] = b[1] ^ ((~b[2]) & b[3]);
		a[7] = b[2] ^ ((~b[3]) & b[4]);
		a[8] = b[3] ^ ((~b[4]) & b[0]);
		a[9] = b[4] ^ ((~b[0]) & b[1]);

		b[0] = a[10];
		b[1] = a[11];
		b[2] = a[12];
		b[3] = a[13];
		b[4] = a[14];
		a[10] = b[0] ^ ((~b[1]) & b[2]);
		a[11] = b[1] ^ ((~b[2]) & b[3]);
		a[12] = b[2] ^ ((~b[3]) & b[4]);
		a[13] = b[3] ^ ((~b[4]) & b[0]);
		a[14] = b[4] ^ ((~b[0]) & b[1]);

		b[0] = a[15];
		b[1] = a[16];
		b[2] = a[17];
		b[3] = a[18];
		b[4] = a[19];
		a[15] = b[0] ^ ((~b[1]) & b[2]);
		a[16] = b[1] ^ ((~b[2]) & b[3]);
		a[17] = b[2] ^ ((~b[3]) & b[4]);
		a[18] = b[3] ^ ((~b[4]) & b[0]);
		a[19] = b[4] ^ ((~b[0]) & b[1]);

		b[0] = a[20];
		b[1] = a[21];
		b[2] = a[22];
		b[3] = a[23];
		b[4] = a[24];
		a[20] = b[0] ^ ((~b[1]) & b[2]);
		a[21] = b[1] ^ ((~b[2]) & b[3]);
		a[22] = b[2] ^ ((~b[3]) & b[4]);
		a[23] = b[3] ^ ((~b[4]) & b[0]);
		a[24] = b[4] ^ ((~b[0]) & b[1]);

		// Iota
		a[0] ^= Keccak_f1600_RC[i];
	}
}

// The following was forked by kayabaNerve from 0age's work

/*
MIT License

Copyright (c) 2019 0age
Copyright (c) 2024 Luke Parker

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

__kernel void hashMessage(
  __global volatile ulong *restrict solutions
) {

  ulong spongeBuffer[25];

#define sponge ((uchar *) spongeBuffer)
#define digest sponge

  sponge[0] = S_0;
  sponge[1] = S_1;
  sponge[2] = S_2;
  sponge[3] = S_3;
  sponge[4] = S_4;
  sponge[5] = S_5;
  sponge[6] = S_6;
  sponge[7] = S_7;
  sponge[8] = S_8;
  sponge[9] = S_9;
  sponge[10] = S_10;
  sponge[11] = S_11;
  sponge[12] = S_12;
  sponge[13] = S_13;
  sponge[14] = S_14;
  sponge[15] = S_15;
  sponge[16] = S_16;
  sponge[17] = S_17;
  sponge[18] = S_18;
  sponge[19] = S_19;
  sponge[20] = S_20;
  sponge[21] = S_21;
  sponge[22] = S_22;
  sponge[23] = S_23;
  sponge[24] = S_24;
  sponge[25] = S_25;
  sponge[26] = S_26;
  sponge[27] = S_27;
  sponge[28] = S_28;
  sponge[29] = S_29;
  sponge[30] = S_30;
  sponge[31] = S_31;
  sponge[32] = S_32;
  sponge[33] = S_33;
  sponge[34] = S_34;
  sponge[35] = S_35;
  sponge[36] = S_36;
  sponge[37] = S_37;
  sponge[38] = S_38;
  sponge[39] = S_39;
  sponge[40] = S_40;
  sponge[41] = S_41;
  sponge[42] = S_42;
  sponge[43] = S_43;
  sponge[44] = S_44;
  sponge[45] = S_45;
  sponge[46] = S_46;
  sponge[47] = S_47;
  sponge[48] = S_48;
  sponge[49] = S_49;
  sponge[50] = S_50;
  sponge[51] = S_51;
  sponge[52] = S_52;
  sponge[53] = S_53;
  sponge[54] = S_54;
  sponge[55] = S_55;
  sponge[56] = S_56;
  sponge[57] = S_57;
  sponge[58] = S_58;
  sponge[59] = S_59;
  sponge[60] = S_60;
  sponge[61] = S_61;
  sponge[62] = S_62;
  sponge[63] = S_63;
  sponge[64] = S_64;
  sponge[65] = S_65;
  sponge[66] = S_66;
  sponge[67] = S_67;
  sponge[68] = S_68;
  sponge[69] = S_69;
  sponge[70] = S_70;
  sponge[71] = S_71;
  sponge[72] = S_72;
  sponge[73] = S_73;
  sponge[74] = S_74;
  sponge[75] = S_75;
  sponge[76] = S_76;
  sponge[77] = S_77;
  sponge[78] = S_78;
  sponge[79] = S_79;
  sponge[80] = S_80;
  sponge[81] = S_81;
  sponge[82] = S_82;
  sponge[83] = S_83;
  sponge[84] = S_84;
  sponge[85] = S_85;
  sponge[86] = S_86;
  sponge[87] = S_87;
  sponge[88] = S_88;
  sponge[89] = S_89;
  sponge[90] = S_90;
  sponge[91] = S_91;
  sponge[92] = S_92;
  sponge[93] = S_93;
  sponge[94] = S_94;
  sponge[95] = S_95;
  sponge[96] = S_96;
  sponge[97] = S_97;
  sponge[98] = S_98;
  sponge[99] = S_99;
  sponge[100] = S_100;
  sponge[101] = S_101;
  sponge[102] = S_102;
  sponge[103] = S_103;
  sponge[104] = S_104;
  sponge[105] = S_105;
  sponge[106] = S_106;
  sponge[107] = S_107;
  sponge[108] = S_108;
  sponge[109] = S_109;
  sponge[110] = S_110;
  sponge[111] = S_111;
  sponge[112] = S_112;
  sponge[113] = S_113;
  sponge[114] = S_114;
  sponge[115] = S_115;
  sponge[116] = S_116;
  sponge[117] = S_117;
  sponge[118] = S_118;
  sponge[119] = S_119;
  sponge[120] = S_120;
  sponge[121] = S_121;
  sponge[122] = S_122;
  sponge[123] = S_123;
  sponge[124] = S_124;
  sponge[125] = S_125;
  sponge[126] = S_126;
  sponge[127] = S_127;
  sponge[128] = S_128;
  sponge[129] = S_129;
  sponge[130] = S_130;
  sponge[131] = S_131;
  sponge[132] = S_132;
  sponge[133] = S_133;
  sponge[134] = S_134;
  sponge[135] = S_135;

  // Write the nonce
  uint nonce = get_global_id(0);
#pragma unroll
  for (int i = 0; i < 6; ++i) {
    size_t shift = 24 - ((i + 1) * 4);
    uint nibble = (nonce >> shift) & 0xf;
    uchar dec_encoding = (uchar) (nibble < 10);
    uchar alpha_encoding = 1 - dec_encoding;
    sponge[NONCE_START_POS + i] = (dec_encoding * ('0' + nibble)) + (alpha_encoding * ('A' + (nibble - 10)));
  }

  // fill remaining sponge state with zeroes
#pragma unroll
  for (int i = 136; i < 200; ++i)
    sponge[i] = 0;

  // Apply keccakf
  keccakf(spongeBuffer);

  // determine if the address meets the constraints
  if ((digest[0] == T_0) && (digest[1] == T_1) && (digest[2] == T_2) && (digest[3] == T_3)) {
    // To be honest, if we are using OpenCL,
    // we just need to write one solution for all practical purposes,
    // since the chance of multiple solutions appearing
    // in a single workset is extremely low.
    solutions[0] = (ulong) nonce;
  }
}
