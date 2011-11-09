#include <stdio.h>
int add(int z, int x)
{
    int c = z + x;
    return c;
}

int main()
{
    int q = 1;
    int w = 2;
    int e = add(q, w);
    e++;
    e++;

    printf("%d\n", e);

    /* unbreakable line */
    int breakable_line = 1;
    /* other unbreakable line */
}
