NR > 1 {
	count[$2] += 1
	max = $2 > max ? $2 : max
	sum += $2
}
END {
	for(i = 0; i <= max; i++)
		printf("%d buckets with %d items\n", count[i], i)
	printf("%d items total\n", sum)
}
