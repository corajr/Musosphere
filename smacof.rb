def getDissimilarities(f)
  dis = Matrix.build(f.row_size, f.column_size) { |i, j|
      Math.sqrt( (f[i, i] * f[j, j]) / f[j, i])
  }
	return dis
end

def smacof(freqs, coords, threshold)
  i = 0
# dissimilarities = getDissimilarities(freqs)
  dissimilarities = freqs
  previousStress = 100000
  distances = euclideanDistances(coords)
  stress = getStress(coords, dissimilarities, distances)
  while previousStress - stress > threshold
    i = i.succ
    previousStress = stress
    coords = updateCoords(coords, dissimilarities, distances)
    distances = euclideanDistances(coords)
    stress = getStress(coords, dissimilarities, distances)
    p stress
    if previousStress - stress < 0
      raise 'Stress function has increased'
    end
    visualize(coords)
  end
end

def euclideanDistances(coords)
  x_array = []
  (0..coords.row_size - 1).each do |i|
    sum = 0
    (0..coords.column_size - 1).each do |j|
      sum += coords[i, j] ** 2
    end
    x_array << [sum]
  end
  x = Matrix[*x_array]
  y = x.transpose
  one_n = Matrix.build(coords.row_size, 1) { 1 }
  one_m = one_n.transpose
  d = x * one_m
  d += one_n * y
  d -= (2 * coords * coords.transpose)
  d_sqrt = Matrix.build(d.row_size, d.column_size) {|i, j| Math.sqrt(d[i, j]) }
  return d_sqrt
end

def getStress(coords, dissimilarities, distances)
  sumNumerator = 0
  sumDenominator = 0
  dissimilarities.each_with_index do |d, i, j|
    sumNumerator += (d - distances[i, j]) ** 2
    sumDenominator += d ** 2
  end
  return sumNumerator / sumDenominator
end

def updateCoords(oldCoords, dissimilarities, distances)
  n = oldCoords.row_size
  z_0 = Matrix.build(n, n) {|i,j|
      if i != j and distances[i, j] > 0
        -dissimilarities[i, j] / distances[i, j]
      elsif i != j and distances[i, j] == 0
         0
      end
  }
  z_1 = z_0.to_a
  (0..n-1).each do |i|
    sum = 0
    (0..n-1).each do |j|
      if i != j
        sum += z_1[i][j]
      end
    end
    z_1[i][i] = -sum
  end
  z = Matrix[*z_1]
  x = (1.0/n) * z * oldCoords;
  return x
end

def visualize(coords)
  i = 0
  $spheres.each do |id, s|
    s.pos.x = coords[i, 0]
    s.pos.y = coords[i, 1]
    if coords.column_size > 2
      s.pos.z = coords[i, 2]
    end
    i = i.succ
  end
end
