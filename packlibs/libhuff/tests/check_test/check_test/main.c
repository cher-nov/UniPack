#include <stdio.h>
#define COUNT_TESTS 5
int main() {
    for (int i = 1; i <= COUNT_TESTS; i++)  {
        char test_name[100];
        sprintf(test_name, "test%d.out", i);
        FILE* test = fopen(test_name, "rb");
    
        sprintf(test_name, "test%d.in", i);
        FILE* checker = fopen(test_name, "rb");
    
        while (!feof(checker))  {
            unsigned char a = fgetc(test);
            unsigned char b = fgetc(checker);
            if (a != b)  {
                printf("Wrong answer");
                return 0;
            }
        }
        if (!feof(test))  {
            printf("Wrong answer");
            return 0;
        }
    
        printf("OK");
    }
    return 0;
}
