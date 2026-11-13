/*
* Logic Quest (LQ): Task 3A Path Planner with Decryption
*
* Computes the shortest path on the Logic Quest arena (nodes N1..N36), with the
* line weights of Figure 1 on the Task 3A page: straight line 5, ring arcs
* 7 / 11 / 15 / 19 (inner ring to outermost ring), wavy line N1-N36 100.
*
* Inputs : current_node, next_node, is_encrypted
*   current_node     : where the bot is, 1..36. The path starts here.
*                      At the first location the bot is in the start box, N35.
*   is_encrypted = 0 : next_node is a node number.
*                      Path: current_node -> next_node.
*   is_encrypted = 1 : next_node is the 8-byte encrypted code, encrypted with
*                      PRESENT-80.
*                      Path: current_node -> the drop node in the block.
*
* Decrypted code (8 bytes, byte 0 first):
*   byte 0     : done flag (1 = last block: no pick-up after this drop)
*   byte 1..5  : message, 5 ASCII characters (0x00 = no character)
*   byte 6     : next pick-up node 1..36 (not used when the done flag is 1)
*   byte 7     : drop node 1..36 for this block
*   e.g. message "HELLO", drop at N26, then pick up at N12
*        -> 00 48 45 4C 4C 4F 0C 1A = 0048454C4C4F0C1A
*
* Outputs:
*   is_encrypted = 0 : the path from current_node to next_node.
*   is_encrypted = 1 : the message (message[]) and the path from current_node
*                      to the drop node. When the done flag is 0, the inputs
*                      for the next run are written too:
*                          IS_ENCRYPTED = 0
*                          CURRENT_NODE = the drop node
*                          NEXT_NODE    = the next pick-up node
*                      When the done flag is 1, the inputs are left as they are.
*
* Output (PC), read by test.sh line by line:
*   is_encrypted = 0     is_encrypted = 1, done = 0     is_encrypted = 1, done = 1
*   35                   Message : HELLO                Message : BYE
*   ...                  7                              7
*   7                    ...                            ...
*                        26                             26
*                        Next current_node : 26         Done
*                        Next next_node : 12
*   The path is one node per line, first node first. The message line shows
*   the non-zero message bytes as characters. The code at the end of main
*   prints all of this from message[], path_planned[], idx and the inputs
*   written for the next run.
*
* Debug prints: start every debug line with "dbg:" (see Functions Usage
*   below). test.sh and the evaluator skip the lines that start with "dbg:".
*   Any other extra line counts as part of your output and makes it wrong.
*
* PRESENT-80 (the cipher used for the encrypted codes):
*   block 64 bits, key 80 bits = A1 B2 C3 D4 E5 F6 07 18 29 3A (PRESENT_KEY_* below),
*   31 rounds. See the Task 3A page for the full description of the encryption;
*   your program has to do the reverse.
*
* Data memory ranges (used on the RISC-V CPU, Task 3B):
*   0x02000000 .. 0x0200000F : inputs
*   0x02000010 .. 0x0200001F : outputs (0x0200001C = CPU_DONE)
*   0x02000020 and up        : working memory, stack at the top
*
* Inputs  : ENCRYPTED_HI (0x02000000)  encrypted block, bytes 0..3 (first 8 hex digits)
*           ENCRYPTED_LO (0x02000004)  encrypted block, bytes 4..7 (last 8 hex digits)
*           IS_ENCRYPTED (0x02000008)  0 or 1                            } written for
*           NEXT_NODE    (0x0200000C)  next node, when IS_ENCRYPTED = 0   } the next run
*           CURRENT_NODE (0x0200000D)  current node (where the bot is)    } when done = 0
* Outputs : MESSAGE_0..4 (0x02000010 .. 0x02000014)  message, block bytes 1..5
*           NODE_POINT   (0x02000018)  every node of the path, written in order
*           CPU_DONE     (0x0200001C)  = 1 when finished
*
* Make sure you don't change anything outside the "Add your code here" sections.
*/

#include <stdlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <limits.h>

// PRESENT-80 key: A1 B2 C3 D4 E5 F6 07 18 29 3A
#define PRESENT_KEY_HI  0xA1B2C3D4   // key bits 79..48
#define PRESENT_KEY_MID 0xE5F60718   // key bits 47..16
#define PRESENT_KEY_LO  0x293A       // key bits 15..0

#ifdef __linux__ // for host pc

    #include <stdio.h>

    void _put_byte(char c) { putchar(c); }

    void _put_str(char *str) {
        while (*str) {
            _put_byte(*str++);
        }
    }

    void print_output(uint8_t num) {
        if (num == 0) {
            putchar('0'); // if the number is 0, directly print '0'
            _put_byte('\n');
            return;
        }

        // convert the integer to a string
        char buffer[20];
        uint8_t index = 0;

        while (num > 0) {
            buffer[index++] = '0' + num % 10; // convert the last digit to its character representation
            num /= 10;                        // move to the next digit
        }
        // print the characters in reverse order (from right to left)
        while (index > 0) { putchar(buffer[--index]); }
        _put_byte('\n');
    }

    void _put_value(uint8_t val) { print_output(val); }

    // print a 32-bit value as 8 hex digits and a newline (e.g. the decrypted block)
    void _put_hex(uint32_t val) { printf("%08X\n", (unsigned int)val); }

    // read 16 hex digits into two 32-bit words, returns 0 if the text is not 16 hex digits
    int read_block(const char *hex, uint32_t *hi, uint32_t *lo) {
        uint32_t word[2] = { 0, 0 };
        if (hex[0] == '0' && (hex[1] == 'x' || hex[1] == 'X')) hex += 2;
        for (int n = 0; n < 16; n++) {
            char c = hex[n];
            uint32_t d;
            if      (c >= '0' && c <= '9') d = c - '0';
            else if (c >= 'a' && c <= 'f') d = c - 'a' + 10;
            else if (c >= 'A' && c <= 'F') d = c - 'A' + 10;
            else return 0;
            word[n >> 3] = (word[n >> 3] << 4) | d;
        }
        if (hex[16] != '\0') return 0;
        *hi = word[0];
        *lo = word[1];
        return 1;
    }

    /*
     * On the PC there is no data memory at 0x02000000, so MEM32(address) is a
     * normal array (one entry per 32-bit word). On the CPU it is the real
     * data memory. Either way, MEM32(0x02000020) reads the same place.
     */
    static uint32_t pc_data_mem[128];
    #define MEM32(addr)  (pc_data_mem[((addr) - 0x02000000u) >> 2])

#else  // for the test device

    void _put_byte(char c) { }
    void _put_value(uint8_t val) { }
    void _put_hex(uint32_t val) { }
    void _put_str(char *str) { }

    #define MEM32(addr)  (*(volatile uint32_t *)(addr))

#endif

/*
Functions Usage

To print while debugging, use the functions below, not printf().
On the PC they print. On the CPU they are empty, so they cost nothing there
and the same file still builds with generatehex.sh.

for a character: _put_byte('A');                        (putchar() on the PC)
for newline:     _put_byte('\n');
for string:      _put_str("your string here");
for number:      _put_value(your_number_here);           0 to 255, then a newline
for 32 bits:     _put_hex(your_32_bit_value_here);       8 hex digits, then a newline

Start every debug line with "dbg:" and end it with a newline (_put_value
and _put_hex end the line for you). test.sh and the evaluator skip the
lines that start with "dbg:", so these prints can stay in the file you
submit. Any other line you print counts as part of your output (see
"Output (PC)" at the top) and makes it wrong.

Examples:
        _put_str("dbg: start_point = ");     _put_value(start_point);
        _put_str("dbg: end_point = ");       _put_value(end_point);
        _put_str("dbg: ENCRYPTED_HI = ");    _put_hex(ENCRYPTED_HI);    // encrypted block, bytes 0..3
        _put_str("dbg: ENCRYPTED_LO = ");    _put_hex(ENCRYPTED_LO);    // encrypted block, bytes 4..7
        _put_str("dbg: first character = "); _put_byte(message[0]); _put_byte('\n');
        _put_str("dbg: Hello World!\n");

*/

// Custom Functions

// ############# Add your code here #############
#pragma GCC optimize ("Os,no-move-loop-invariants,no-tree-loop-im,no-code-hoisting,no-gcse,peel-loops")

#define PIS(x) ((uint8_t)(((((x) & 8u) ? 0xA970364Bu : 0xD21C8FE5u) >> (((x) & 7u) << 2)) & 15u))
static inline __attribute__((always_inline)) uint64_t dec(uint32_t a, uint32_t b) {
    uint32_t h = 0x396CEC47u, v = 0x603521D0u, l = 0xD508u;
    a ^= h; b ^= v;
    for (uint32_t r = 31u; r; --r) {
        uint32_t t, x = 0, y = 0;
        v ^= (uint32_t)(r >> 1);
        l ^= (r << 31) >> 16;
        t = h + (((uint32_t)PIS(h >> 28) - (h >> 28)) << 28);
        h = (t << 19) | (v >> 13);
        v = (v << 19) | (l << 3) | (t >> 29);
        l = (t << 3) >> 16;
        for (uint8_t c = 16u; c--; ) {
            uint32_t nib = ((b >> c) & 1u) | (((b >> (c + 16u)) & 1u) << 1)
                         | (((a >> c) & 1u) << 2) | (((a >> (c + 16u)) & 1u) << 3);
            x = (x << 4) | (y >> 28);
            y = (y << 4) | PIS(nib);
        }
        a = x ^ h; b = y ^ v;
    }
    return ((uint64_t)a << 32) | b;
}

static inline __attribute__((always_inline)) uint8_t nxt(uint8_t src, uint8_t dst) {
    uint32_t ra, rb, rc, ev;
    uint8_t m = (uint8_t)(src - 1u);
    if (m & 32u) {
        if (m & 2u) {
            if (m & 1u) {
                ra = 0x00000000u;
                rb = 0x00000000u;
                rc = 0x00000000u;
                ev = 0x00000001u;
            } else {
                ra = 0x40514000u;
                rb = 0x51555555u;
                rc = 0x00000004u;
                ev = 0x000007DEu;
            }
        } else {
            if (m & 1u) {
                ra = 0x00000000u;
                rb = 0x00000000u;
                rc = 0x00000000u;
                ev = 0x0000001Fu;
            } else {
                ra = 0x00000000u;
                rb = 0x00000000u;
                rc = 0x00000000u;
                ev = 0x0000001Eu;
            }
        }
    } else {
        if (m & 16u) {
            if (m & 8u) {
                if (m & 4u) {
                    if (m & 2u) {
                        if (m & 1u) {
                            ra = 0x01000000u;
                            rb = 0x14400000u;
                            rc = 0x00000015u;
                            ev = 0x0000071Du;
                        } else {
                            ra = 0x2A082088u;
                            rb = 0x08000000u;
                            rc = 0x00000026u;
                            ev = 0x0002389Cu;
                        }
                    } else {
                        if (m & 1u) {
                            ra = 0x95555555u;
                            rb = 0xA2AAA956u;
                            rc = 0x00000068u;
                            ev = 0x00023361u;
                        } else {
                            ra = 0x15555555u;
                            rb = 0xA8904154u;
                            rc = 0x0000006Au;
                            ev = 0x000206DAu;
                        }
                    }
                } else {
                    if (m & 2u) {
                        if (m & 1u) {
                            ra = 0x40555511u;
                            rb = 0x41155555u;
                            rc = 0x00000040u;
                            ev = 0x0000081Fu;
                        } else {
                            ra = 0x95555555u;
                            rb = 0xAA8A2956u;
                            rc = 0x0000006Au;
                            ev = 0x0001D518u;
                        }
                    } else {
                        if (m & 1u) {
                            ra = 0x15555555u;
                            rb = 0x55504154u;
                            rc = 0x00000055u;
                            ev = 0x00000757u;
                        } else {
                            ra = 0x55555555u;
                            rb = 0x55545155u;
                            rc = 0x00000055u;
                            ev = 0x000005D6u;
                        }
                    }
                }
            } else {
                if (m & 4u) {
                    if (m & 2u) {
                        if (m & 1u) {
                            ra = 0x00000000u;
                            rb = 0x00000000u;
                            rc = 0x00000000u;
                            ev = 0x0000001Bu;
                        } else {
                            ra = 0x2AAAAAAAu;
                            rb = 0xAAA986A8u;
                            rc = 0x000000AAu;
                            ev = 0x0001A650u;
                        }
                    } else {
                        if (m & 1u) {
                            ra = 0x00000000u;
                            rb = 0x00000000u;
                            rc = 0x00000000u;
                            ev = 0x00000019u;
                        } else {
                            ra = 0x00000000u;
                            rb = 0x00000000u;
                            rc = 0x00000000u;
                            ev = 0x00000014u;
                        }
                    }
                } else {
                    if (m & 2u) {
                        if (m & 1u) {
                            ra = 0x95555555u;
                            rb = 0xA6AAA816u;
                            rc = 0x00000069u;
                            ev = 0x0001B215u;
                        } else {
                            ra = 0x55555555u;
                            rb = 0x55555541u;
                            rc = 0x00000055u;
                            ev = 0x000002D2u;
                        }
                    } else {
                        if (m & 1u) {
                            ra = 0x00000000u;
                            rb = 0x00000000u;
                            rc = 0x00000000u;
                            ev = 0x00000013u;
                        } else {
                            ra = 0x00000000u;
                            rb = 0x00000000u;
                            rc = 0x00000000u;
                            ev = 0x00000010u;
                        }
                    }
                }
            }
        } else {
            if (m & 8u) {
                if (m & 4u) {
                    if (m & 2u) {
                        if (m & 1u) {
                            ra = 0x15555555u;
                            rb = 0x55555554u;
                            rc = 0x00000055u;
                            ev = 0x000005D1u;
                        } else {
                            ra = 0x40555511u;
                            rb = 0x41155555u;
                            rc = 0x00000040u;
                            ev = 0x000001CEu;
                        }
                    } else {
                        if (m & 1u) {
                            ra = 0x505559AAu;
                            rb = 0x41155555u;
                            rc = 0x00000080u;
                            ev = 0x000043CDu;
                        } else {
                            ra = 0x00000000u;
                            rb = 0x54400000u;
                            rc = 0x00000015u;
                            ev = 0x0000078Eu;
                        }
                    }
                } else {
                    if (m & 2u) {
                        if (m & 1u) {
                            ra = 0x00000000u;
                            rb = 0x00000000u;
                            rc = 0x00000000u;
                            ev = 0x00000009u;
                        } else {
                            ra = 0x00410000u;
                            rb = 0x00000028u;
                            rc = 0x00000000u;
                            ev = 0x00013248u;
                        }
                    } else {
                        if (m & 1u) {
                            ra = 0x00000000u;
                            rb = 0x00000000u;
                            rc = 0x00000000u;
                            ev = 0x00000007u;
                        } else {
                            ra = 0x00400000u;
                            rb = 0x00000000u;
                            rc = 0x00000000u;
                            ev = 0x0000030Bu;
                        }
                    }
                }
            } else {
                if (m & 4u) {
                    if (m & 2u) {
                        if (m & 1u) {
                            ra = 0x80510000u;
                            rb = 0xA2AAAA96u;
                            rc = 0x00000028u;
                            ev = 0x000142C5u;
                        } else {
                            ra = 0x2A040000u;
                            rb = 0x28000000u;
                            rc = 0x0000002Au;
                            ev = 0x0000F285u;
                        }
                    } else {
                        if (m & 1u) {
                            ra = 0x55555145u;
                            rb = 0x55555555u;
                            rc = 0x00000055u;
                            ev = 0x00000043u;
                        } else {
                            ra = 0x95A69000u;
                            rb = 0xA6AAAAAAu;
                            rc = 0x00000019u;
                            ev = 0x000081C1u;
                        }
                    }
                } else {
                    if (m & 2u) {
                        if (m & 1u) {
                            ra = 0x6A555511u;
                            rb = 0x69955555u;
                            rc = 0x0000006Au;
                            ev = 0x0000E042u;
                        } else {
                            ra = 0x00000000u;
                            rb = 0x00000000u;
                            rc = 0x00000000u;
                            ev = 0x00000006u;
                        }
                    } else {
                        if (m & 1u) {
                            ra = 0x00000000u;
                            rb = 0x00000000u;
                            rc = 0x00000000u;
                            ev = 0x00000004u;
                        } else {
                            ra = 0x5A555DB8u;
                            rb = 0x59555555u;
                            rc = 0x00000026u;
                            ev = 0x00184164u;
                        }
                    }
                }
            }
        }
    }
    uint8_t i = (uint8_t)(dst - 1u);
    uint32_t row = (i & 32u) ? rc : ((i & 16u) ? rb : ra);
    uint8_t k = (uint8_t)((row >> ((i & 15u) << 1)) & 3u);
    return (uint8_t)((ev >> ((k << 2) + (k << 1))) & 63u);
}

// ##############################################

// main function
int main(int argc, char const *argv[]) {

    #ifdef __linux__

        if (argc < 4) {
            _put_str("usage: ./Path_Planner_Dec <current_node> <next_node> <is_encrypted>\n");
            _put_str("       current_node     : where the bot is, e.g. 35 (the start box)\n");
            _put_str("       is_encrypted = 0 : next_node is a node number, e.g. 7\n");
            _put_str("       is_encrypted = 1 : next_node is the encrypted code, 16 hex digits\n");
            return 1;
        }
        uint8_t  CURRENT_NODE        = atoi(argv[1]);
        uint8_t  IS_ENCRYPTED        = atoi(argv[3]);
        uint8_t  NEXT_NODE           = 0;
        uint32_t ENCRYPTED_HI        = 0;
        uint32_t ENCRYPTED_LO        = 0;
        if (IS_ENCRYPTED) {
            if (!read_block(argv[2], &ENCRYPTED_HI, &ENCRYPTED_LO)) {
                _put_str("with is_encrypted = 1, next_node must be exactly 16 hex digits\n");
                return 1;
            }
        }
        else {
            NEXT_NODE = atoi(argv[2]);
        }
        uint8_t MESSAGE_0           = 0;
        uint8_t MESSAGE_1           = 0;
        uint8_t MESSAGE_2           = 0;
        uint8_t MESSAGE_3           = 0;
        uint8_t MESSAGE_4           = 0;
        uint8_t NODE_POINT          = 0;
        uint8_t CPU_DONE            = 0;

    #else
        // Address value of variables are updated for RISC-V Implementation
        // inputs: 0x02000000 .. 0x0200000F
        #define ENCRYPTED_HI        (* (volatile uint32_t * ) 0x02000000)
        #define ENCRYPTED_LO        (* (volatile uint32_t * ) 0x02000004)
        #define IS_ENCRYPTED        (* (volatile uint8_t  * ) 0x02000008)
        #define NEXT_NODE           (* (volatile uint8_t  * ) 0x0200000c)
        #define CURRENT_NODE        (* (volatile uint8_t  * ) 0x0200000d)
        // outputs: 0x02000010 .. 0x0200001F
        #define MESSAGE_0           (* (volatile uint8_t  * ) 0x02000010)
        #define MESSAGE_1           (* (volatile uint8_t  * ) 0x02000011)
        #define MESSAGE_2           (* (volatile uint8_t  * ) 0x02000012)
        #define MESSAGE_3           (* (volatile uint8_t  * ) 0x02000013)
        #define MESSAGE_4           (* (volatile uint8_t  * ) 0x02000014)
        #define NODE_POINT          (* (volatile uint8_t  * ) 0x02000018)
        #define CPU_DONE            (* (volatile uint8_t  * ) 0x0200001c)

    #endif

    // read once here: for the next run, the program may write IS_ENCRYPTED = 0
    uint8_t is_encrypted = IS_ENCRYPTED;

    // the message: bytes 1..5 of the decrypted block (0x00 = no character)
    uint8_t message[5] = { 0, 0, 0, 0, 0 };

    // array to store the planned path
    uint8_t path_planned[40];
    // index to keep track of the path_planned array
    uint8_t idx = 0;

    uint8_t start_point = CURRENT_NODE;   // where the bot is
    uint8_t end_point   = 0;              // where the bot goes

    // ############# Add your code here #############
    uint8_t tgt;
    uint64_t q = 0;
    if (is_encrypted) {
        q = dec(ENCRYPTED_HI, ENCRYPTED_LO);
        tgt = (uint8_t)q;
        end_point = tgt;
        if ((uint8_t)(q >> 56) > 1u || tgt < 1u || tgt > 36u) return 1;
        if (!(uint8_t)(q >> 56)) {
            uint8_t next = (uint8_t)(q >> 8);
            if (next < 1u || next > 36u) return 1;
        }
    } else {
        tgt = NEXT_NODE;
        end_point = tgt;
        if (tgt < 1u || tgt > 36u) return 1;
    }
    uint8_t cur = CURRENT_NODE;
    if (cur < 1u || cur > 36u) return 1;

    uint32_t P0 = cur, P1 = 0u, P2 = 0u;
    uint8_t i = 0u;
    for (;;) {
        if (cur == tgt) {
            idx = (uint8_t)(i + 1u);
            break;
        }
        uint8_t n = nxt(cur, tgt);
        if (!n) return 1;
        if (++i > 12u) return 1;
        cur = n;
        uint8_t sh = (uint8_t)((i << 2) + (i << 1));
        if (i < 5u) P0 |= (uint32_t)n << sh;
        else if (i < 10u) P1 |= (uint32_t)n << (uint8_t)(sh - 30u);
        else P2 |= (uint32_t)n << (uint8_t)(sh - 60u);
    }
    path_planned[0]  = (uint8_t)(P0 & 63u);
    path_planned[1]  = (uint8_t)((P0 >> 6) & 63u);
    path_planned[2]  = (uint8_t)((P0 >> 12) & 63u);
    path_planned[3]  = (uint8_t)((P0 >> 18) & 63u);
    path_planned[4]  = (uint8_t)((P0 >> 24) & 63u);
    path_planned[5]  = (uint8_t)(P1 & 63u);
    path_planned[6]  = (uint8_t)((P1 >> 6) & 63u);
    path_planned[7]  = (uint8_t)((P1 >> 12) & 63u);
    path_planned[8]  = (uint8_t)((P1 >> 18) & 63u);
    path_planned[9]  = (uint8_t)((P1 >> 24) & 63u);
    path_planned[10] = (uint8_t)(P2 & 63u);
    path_planned[11] = (uint8_t)((P2 >> 6) & 63u);
    path_planned[12] = (uint8_t)((P2 >> 12) & 63u);

    if (is_encrypted) {
        message[0] = (uint8_t)(q >> 48);
        message[1] = (uint8_t)(q >> 40);
        message[2] = (uint8_t)(q >> 32);
        message[3] = (uint8_t)(q >> 24);
        message[4] = (uint8_t)(q >> 16);
        if (!(uint8_t)(q >> 56)) {
            IS_ENCRYPTED = 0;
            NEXT_NODE = (uint8_t)(q >> 8);
            CURRENT_NODE = (uint8_t)q;
        }
    }
    // ##############################################

    // the message bytes are written into data memory (encrypted block only).
    if (is_encrypted) {
        MESSAGE_0 = message[0];
        MESSAGE_1 = message[1];
        MESSAGE_2 = message[2];
        MESSAGE_3 = message[3];
        MESSAGE_4 = message[4];
    }
    // the node values are written into data memory sequentially.
    for (int i = 0; i < idx; ++i) {
        NODE_POINT = path_planned[i];
    }
    // Path Planning Computation Done Flag
    CPU_DONE = 1;

    #ifdef __linux__    // for host pc: the output test.sh reads (see "Output (PC)" at the top)

        if (is_encrypted) {
            _put_str("Message : ");
            for (int i = 0; i < 5; ++i) {
                if (message[i]) _put_byte(message[i]);
            }
            _put_byte('\n');
        }
        for (int i = 0; i < idx; ++i) {
            _put_value(path_planned[i]);
        }
        if (is_encrypted) {
            if (IS_ENCRYPTED == 0) {            // the inputs written for the next run
                _put_str("Next current_node : ");
                _put_value(CURRENT_NODE);
                _put_str("Next next_node : ");
                _put_value(NEXT_NODE);
            }
            else {
                _put_str("Done\n");
            }
        }

    #endif

    return 0;
}
